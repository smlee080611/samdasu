shader_type canvas_item;
// 몸 상태를 화면으로 보여준다.
// stiff(0~1): 화면 가장자리부터 회색 돌처럼 변한다.  grab(0~1): 붙잡혔을 때 붉게 번진다.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise : repeat_enable;
uniform float stiff = 0.0;
uniform float grab = 0.0;
uniform float aspect = 1.7778;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(d) / (0.5 * length(vec2(aspect, 1.0)));   // 화면 중앙 0, 모서리 1
	float n = texture(noise, uv * vec2(aspect, 1.0) * 1.5).r;
	float n2 = texture(noise, uv * vec2(aspect, 1.0) * 6.0 + 0.37).r;
	// 굳음이 오를수록 돌 영역이 안쪽으로 파고든다. 노이즈로 경계를 울퉁불퉁하게.
	float reach = 1.08 - stiff * 0.62;
	float edge = smoothstep(reach - 0.06, reach + 0.04, r + (n - 0.5) * 0.28);
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 stone = vec3(0.40, 0.41, 0.43) * (0.55 + n2 * 0.7) + g * 0.35;
	c = mix(c, stone, edge * smoothstep(0.03, 0.25, stiff));
	// 돌 경계 바로 안쪽은 색이 빠진다
	float fade = smoothstep(reach - 0.35, reach, r) * stiff;
	c = mix(c, vec3(g), fade * 0.8);
	// 기본 비네트
	c *= 1.0 - smoothstep(0.45, 1.05, r) * 0.55;
	// 붙잡힘
	c = mix(c, vec3(0.55, 0.04, 0.02), grab * smoothstep(0.2, 0.95, r) * 0.85);
	COLOR = vec4(c, 1.0);
}
