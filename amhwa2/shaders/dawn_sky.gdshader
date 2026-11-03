shader_type sky;
// 밤하늘(sky.png 파노라마) 위에 새벽빛을 겹친다. night.gd가 dawn(0~1)을 올린다.
// 지평선 쪽이 먼저 붉게 밝아지고, 해가 뜰 무렵에야 하늘 전체가 푸르게 밝아진다.
// 병원 안 밝기(ambient)는 색 고정이라 하늘이 밝아져도 실내는 그대로 어둡다. 창밖으로만 보인다.

uniform sampler2D panorama : source_color, filter_linear, hint_default_black;
uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec3 horizon_dawn : source_color = vec3(0.95, 0.55, 0.32);
uniform vec3 zenith_dawn : source_color = vec3(0.36, 0.52, 0.8);

void sky() {
	vec3 night = texture(panorama, SKY_COORDS).rgb;
	float h = clamp(EYEDIR.y, -0.2, 1.0);
	float glow = smoothstep(0.0, 0.7, dawn) * exp(-max(h, 0.0) * 4.0);   // 지평선의 붉은 기운
	float day = smoothstep(0.55, 1.0, dawn);                             // 하늘 전체가 밝아짐
	vec3 dawn_col = mix(horizon_dawn, zenith_dawn, smoothstep(0.0, 0.5, h));
	vec3 c = night * (1.0 - day * 0.9);          // 별이 흐려진다
	c = mix(c, horizon_dawn * 0.55, glow * 0.85);
	c = mix(c, dawn_col, day);
	COLOR = c;
}
