// CAT Ocean Flow 셰이더 본체.
// 스크립트가 "shader_type spatial;" + 켠 기능의 #define + 이 파일 #include 로 변형을 만든다.
// 기능 define: WAVE_ON, FOAM_SHORE, CELL_FOAM, NOISE_CHURN, SPECULAR

// 수면이 깊이를 쓰면 자기 자신이 깊이 텍스처에 들어가 포말 계산이 깨지므로 depth_draw_never.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, world_vertex_coords, shadows_disabled;

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform vec4 flow_tiling = vec4(4.0, 4.0, 7.0, 7.0);   // xy = 채널0, zw = 채널1
uniform vec4 flow_offsets = vec4(0.0);                // xy = 채널0, zw = 채널1 (스크립트가 매 프레임 갱신)

// 난류. 위상 인덱스·해시·회전은 픽셀과 무관한 프레임 상수라 스크립트가 계산해 올린다.
uniform vec4 churn_params = vec4(0.0);   // x = 채널0 B 가중치, y = 채널1 B 가중치, z = 워프 세기, w = 시간
uniform vec4 churn0_a = vec4(0.0, 0.0, 1.0, 0.0);   // xy = 재배치 오프셋, z = cos, w = sin
uniform vec4 churn0_b = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 churn1_a = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 churn1_b = vec4(0.0, 0.0, 1.0, 0.0);

// 표면 전용. 강은 기본값을 유지한다.
uniform vec4 uv_world_offset = vec4(0.0, 0.0, 1.0, 1.0);   // xy = 추적 UV 보정, zw = 1 / uv_tiling
uniform float wave_edge_fade = 0.0;

uniform vec4 shallow_color : source_color = vec4(0.45, 0.9, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.28, 0.55, 1.0);
uniform float shallow_alpha = 0.5;
uniform float deep_alpha = 0.95;
uniform float depth_fade_distance = 3.0;

uniform vec4 foam_color : source_color = vec4(1.0);
uniform float foam_distance = 0.6;
uniform float foam_cutoff = 0.6;
uniform float foam_softness = 0.04;
uniform float foam_noise_amount = 0.35;
uniform float foam_alpha = 1.0;
uniform vec2 foam_view_fade = vec2(1000000.0, 1000001.0);

uniform vec4 cell_color : source_color = vec4(1.0);
uniform float cell_cutoff = 0.72;
uniform float cell_softness = 0.03;
uniform float cell_intensity = 0.5;

uniform vec4 highlight_color : source_color = vec4(1.0);
uniform float highlight_power = 64.0;
uniform float highlight_cutoff = 0.5;
uniform float highlight_intensity = 0.8;
uniform vec3 light_direction = vec3(0.0, 1.0, 0.0);   // 빛 쪽을 향하는 월드 방향
uniform vec3 light_color = vec3(1.0);                 // 색 × 에너지

uniform vec4 wave_a = vec4(1.0, 0.0, 0.25, 8.0);   // xy = 방향, z = 가파름, w = 파장
uniform vec4 wave_b = vec4(0.34, 0.94, 0.15, 5.1);
uniform vec4 ripple = vec4(0.04, 3.0, 1.5, 0.0);   // x = 진폭, y = 주파수, z = 속도
uniform vec4 wave_variation = vec4(0.0, 0.0, 0.025, 0.0);   // x = 위상 지터, y = 너울 변화, z = 1 / 너울 크기
uniform vec4 breakup_params = vec4(0.0, 0.04, 0.0, 0.0);    // x = 얼룩 세기, y = 1 / 얼룩 크기, z = 하이라이트 법선 비틀기

uniform float depth_available = 1.0;

varying vec4 v_uv01;
varying vec3 v_world_pos;
varying vec3 v_world_normal;
#if defined(CELL_FOAM) || defined(SPECULAR)
varying vec3 v_breakup;   // x = 얼룩 -1(성김) ~ 1(빽빽함) × 세기(0 이면 균일), yz = 하이라이트용 법선 기울기(월드 xz)
#endif

// 텍스처 없이 만드는 저주파 값(약 -1~1). 방향·주파수가 서로 무리수비라 반복 무늬가 드러나지 않는다.
// p 는 주기 단위(1 = 주 성분 한 주기). 정점 셰이더에서만 쓴다.
float cat_lowfreq(vec2 p, float t) {
	p *= 6.28318530718;
	return (sin(dot(p, vec2(0.799, 0.602)) + t * 0.37)
			+ sin(dot(p, vec2(-0.391, 0.921)) * 1.37 - t * 0.29 + 1.9)
			+ sin(dot(p, vec2(0.966, -0.259)) * 0.73 + t * 0.21 + 4.1)) * 0.33333333;
}

// 텍스처 페치 없이 UV 를 비틀어 그물망 무늬가 통째로 미끄러지는 느낌을 없앤다.
vec2 cat_warp_uv(vec2 uv, float amount, float time) {
	vec2 w;
	w.x = sin(uv.y * 6.2831853 + time * 0.90) + 0.5 * sin(uv.y * 13.7 - time * 1.70);
	w.y = cos(uv.x * 6.2831853 - time * 1.10) + 0.5 * cos(uv.x * 11.3 + time * 1.30);
	return uv + w * amount;
}

// 반주기 엇갈린 두 위상으로 샘플해 교차 페이드한다. 회전은 흐름 오프셋을 뺀 좌표에만 건다.
float cat_sample_churn(vec2 uv, vec2 flow_offset, vec4 phase_a, vec4 phase_b, float weight_b) {
	vec2 base_uv = cat_warp_uv(uv - flow_offset, churn_params.z, churn_params.w);
	vec2 uv_a = vec2(base_uv.x * phase_a.z - base_uv.y * phase_a.w,
			base_uv.x * phase_a.w + base_uv.y * phase_a.z) + flow_offset + phase_a.xy;
	vec2 uv_b = vec2(base_uv.x * phase_b.z - base_uv.y * phase_b.w,
			base_uv.x * phase_b.w + base_uv.y * phase_b.z) + flow_offset + phase_b.xy;
	float noise_a = texture(noise_texture, uv_a).r;
	float noise_b = texture(noise_texture, uv_b).r;
	return mix(noise_a, noise_b, weight_b);
}

// Gerstner 파 하나의 변위. 법선용 접선·종법선 미분을 함께 누적한다.
// phase 는 지역별 위상 비틀기. 저주파라 법선 미분에서는 무시한다.
vec3 cat_gerstner(vec4 wave, vec3 p, float time, float phase, inout vec3 tangent, inout vec3 binormal) {
	vec2 dir = normalize(wave.xy + vec2(1e-5, 0.0));
	float steepness = wave.z;
	float wavelength = max(wave.w, 1e-3);
	float k = 6.28318530718 / wavelength;
	float c = sqrt(9.8 / k);
	float f = k * (dot(dir, p.xz) - c * time) + phase;
	float a = steepness / k;
	float sin_f = sin(f);
	float cos_f = cos(f);
	tangent += vec3(-dir.x * dir.x * steepness * sin_f, dir.x * steepness * cos_f, -dir.x * dir.y * steepness * sin_f);
	binormal += vec3(-dir.x * dir.y * steepness * sin_f, dir.y * steepness * cos_f, -dir.y * dir.y * steepness * sin_f);
	return vec3(dir.x * a * cos_f, a * sin_f, dir.y * a * cos_f);
}

// 패치 가장자리에서 파도 진폭을 0 으로 줄인다. 메쉬 UV 를 0~1 로 되돌려 계산한다.
float cat_wave_edge_fade(vec2 mesh_uv) {
	if (wave_edge_fade <= 0.0) {
		return 1.0;
	}
	vec2 n = mesh_uv * uv_world_offset.zw;
	float edge = max(abs(n.x - 0.5), abs(n.y - 0.5)) * 2.0;
	return 1.0 - smoothstep(1.0 - wave_edge_fade * 2.0, 1.0, edge);
}

void vertex() {
	vec3 normal_ws = vec3(0.0, 1.0, 0.0);
#if defined(CELL_FOAM) || defined(SPECULAR)
	// 거품·반짝임 얼룩. 평균 밀도는 그대로 두고 구역마다 빽빽하거나 성기게 한다.
	// 근거리 패치 가장자리에서는 0 으로 돌려 먼 바다와 이음매가 생기지 않게 한다
	float breakup = smoothstep(-0.55, 0.55, cat_lowfreq(VERTEX.xz * breakup_params.y + vec2(TIME * 0.011, -TIME * 0.007), TIME * 0.2));
	float edge_fade = cat_wave_edge_fade(UV);
	v_breakup = vec3((breakup * 2.0 - 1.0) * breakup_params.x * edge_fade, 0.0, 0.0);
#ifdef SPECULAR
	// 반사 경로가 파도 마루를 따라 평행 띠로 늘어서지 않게 하이라이트 법선만 저주파로 기울인다.
	// 얼룩보다 3배 잘게 두 성분을 따로 만들고, 가장자리는 얼룩처럼 0 으로 돌린다
	vec2 tilt_p = VERTEX.xz * breakup_params.y * 3.0;
	v_breakup.yz = vec2(cat_lowfreq(tilt_p + vec2(5.3, 1.7), TIME * 0.25),
			cat_lowfreq(tilt_p.yx + vec2(-3.1, 8.9), TIME * 0.25 + 3.0)) * (breakup_params.z * 0.3 * edge_fade);
#endif
#endif
#ifdef WAVE_ON
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 base_pos = VERTEX;
	// 지터 공간 주기는 파장의 6배 이상이라 위상 미분이 파수의 절반을 넘지 않는다
	float jitter_a = wave_variation.x * 3.0 * cat_lowfreq(base_pos.xz / max(wave_a.w * 6.0, 1.0), TIME * 0.3);
	float jitter_b = wave_variation.x * 3.0 * cat_lowfreq(base_pos.xz / max(wave_b.w * 6.0, 1.0) + vec2(17.3, -9.1), TIME * 0.3 + 2.0);
	// 너울 묶음: 진폭을 1 이하로만 줄여 컬링 여유가 그대로이고, 가파름에 곱해 법선도 같은 배율을 따른다
	vec2 swell_dir = normalize(wave_a.xy + vec2(1e-5, 0.0));
	float swell = smoothstep(-0.5, 0.5, cat_lowfreq((base_pos.xz - swell_dir * TIME * 1.5) * wave_variation.z, TIME * 0.15));
	float amp = 1.0 - wave_variation.y * 0.7 * swell;
	vec3 displacement = cat_gerstner(vec4(wave_a.xy, wave_a.z * amp, wave_a.w), base_pos, TIME, jitter_a, tangent, binormal);
	displacement += cat_gerstner(vec4(wave_b.xy, wave_b.z * amp, wave_b.w), base_pos, TIME, jitter_b, tangent, binormal);
	// 잔물결: 무리수비 각도(약 37°, 113°, -15°)·주파수비의 방향파 3개. 가중치 합 1 이라 최대 진폭은 ripple.x
	vec2 rp = base_pos.xz * ripple.y;
	float rt = TIME * ripple.z;
	displacement.y += (0.45 * sin(dot(rp, vec2(0.799, 0.602)) + rt + jitter_a)
			+ 0.35 * sin(dot(rp, vec2(-0.391, 0.921)) * 1.37 + rt * 1.13 - jitter_b + 1.3)
			+ 0.2 * sin(dot(rp, vec2(0.966, -0.259)) * 0.83 - rt * 0.87 + jitter_a * 0.7 + 2.9)) * ripple.x;
	float fade = cat_wave_edge_fade(UV);
	VERTEX += displacement * fade;
	normal_ws = normalize(mix(vec3(0.0, 1.0, 0.0), cross(binormal, tangent), fade));
#endif
	NORMAL = normal_ws;
	v_world_normal = normal_ws;
	v_world_pos = VERTEX;

	vec2 base_uv = UV + uv_world_offset.xy;
	v_uv01.xy = base_uv * flow_tiling.xy + flow_offsets.xy;
	v_uv01.zw = base_uv * flow_tiling.zw + flow_offsets.zw;
}

void fragment() {
	// --- 1. 수중 두께 (선형 뷰 깊이 차) ---
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_eye = -view.z / view.w;
	float surface_eye = -VERTEX.z;
	float thickness = max(0.0, scene_eye - surface_eye);
	thickness = mix(depth_fade_distance, thickness, depth_available);

	// --- 2. 깊이 색 그라디언트 ---
	float depth_t = clamp(thickness / max(depth_fade_distance, 1e-4), 0.0, 1.0);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, depth_t);
	float alpha = mix(shallow_alpha, deep_alpha, depth_t);

	// --- 3. 접경 포말 ---
#ifdef FOAM_SHORE
#ifdef NOISE_CHURN
	float noise0 = cat_sample_churn(v_uv01.xy, flow_offsets.xy, churn0_a, churn0_b, churn_params.x);
#else
	float noise0 = texture(noise_texture, v_uv01.xy).r;
#endif
	float edge = 1.0 - clamp(thickness / max(foam_distance, 1e-4), 0.0, 1.0);
	float foam = smoothstep(foam_cutoff - foam_softness, foam_cutoff + foam_softness, edge + noise0 * foam_noise_amount);
	// 먼 물가는 깊이 분해능이 떨어져 띠가 깜빡이므로 거리로 지운다
	foam *= 1.0 - smoothstep(foam_view_fade.x, foam_view_fade.y, surface_eye);
	color = mix(color, foam_color.rgb, foam);
	alpha = max(alpha, foam * foam_alpha);
#endif

	// --- 4. 수면 셀 톤 거품 ---
#ifdef CELL_FOAM
#ifdef NOISE_CHURN
	float noise1 = cat_sample_churn(v_uv01.zw, flow_offsets.zw, churn1_a, churn1_b, churn_params.y);
#else
	float noise1 = texture(noise_texture, v_uv01.zw).r;
#endif
	// 얼룩이 성긴 곳은 문턱을 올려 거품 개수 자체가 줄고, 빽빽한 곳은 늘고 밝아진다
	float cell_cut = cell_cutoff - v_breakup.x * 0.1;
	float cell = smoothstep(cell_cut - cell_softness, cell_cut + cell_softness, noise1);
	color += cell_color.rgb * (cell * cell_intensity * (1.0 + v_breakup.x * 0.5));
#endif

	// --- 5. 셀 톤 하이라이트 ---
#ifdef SPECULAR
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	vec3 half_dir = normalize(light_direction + view_dir);
	float ndoth = clamp(dot(normalize(v_world_normal + vec3(v_breakup.y, 0.0, v_breakup.z)), half_dir), 0.0, 1.0);
#ifdef CELL_FOAM
	// 평평한 수면에서 하이라이트가 면 전체에 켜지거나 꺼지지 않도록 수면 노이즈로 흔든다
	// 얼룩이 성긴 곳일수록 더 크게 흔들어 반짝임이 띠로 이어지지 않고 흩어지게 한다
	ndoth = clamp(ndoth + (noise1 - 0.5) * 0.12 * (1.0 - v_breakup.x * 0.5), 0.0, 1.0);
#endif
	// 얼룩이 성긴 곳은 경계를 올려 반짝임 개수 자체가 줄고, 빽빽한 곳은 는다
	float spec_cut = highlight_cutoff - v_breakup.x * 0.15;
	float spec = smoothstep(spec_cut - 0.02, spec_cut + 0.02, pow(ndoth, max(highlight_power, 1.0)));
	color += highlight_color.rgb * light_color * (spec * highlight_intensity * (1.0 + v_breakup.x * 0.5));
#endif

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
