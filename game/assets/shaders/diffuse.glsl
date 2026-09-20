// Use LÖVE's default precision so effect matches its generated WebGL declaration.
uniform vec2 screenSize;

vec4 effect(
    vec4 color,
    Image texture,
    vec2 texture_coords,
    vec2 screen_coords
)
{
    vec2 px = 1.0 / screenSize;

    vec3 result = vec3(0.0);

    result += Texel(texture, texture_coords + vec2(-px.x, -px.y)).rgb;
    result += Texel(texture, texture_coords + vec2( 0.0,   -px.y)).rgb;
    result += Texel(texture, texture_coords + vec2( px.x,  -px.y)).rgb;

    result += Texel(texture, texture_coords + vec2(-px.x,  0.0)).rgb;
    result += Texel(texture, texture_coords).rgb;
    result += Texel(texture, texture_coords + vec2( px.x,  0.0)).rgb;

    result += Texel(texture, texture_coords + vec2(-px.x,  px.y)).rgb;
    result += Texel(texture, texture_coords + vec2( 0.0,    px.y)).rgb;
    result += Texel(texture, texture_coords + vec2( px.x,   px.y)).rgb;

    result /= 9.0;

    return vec4(result, 1.0) * color;
}
