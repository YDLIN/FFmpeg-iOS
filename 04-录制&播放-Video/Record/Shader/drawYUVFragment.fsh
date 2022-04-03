#version 300 es
precision highp float;
// coord
in vec2 varyTextCoordinate;
uniform int yuvType;//0: I420, 1: NV12
out vec4 fragColor;

// sampler
uniform sampler2D textureY;// I420 -> Y
uniform sampler2D textureU;// I420 -> U
uniform sampler2D textureV;// I420 -> V
uniform sampler2D texture_Y;// NV12 -> Y
uniform sampler2D texture_UV;// NV12 -> UV


const vec3 delyuv = vec3(-0.0/255.0, -128.0/255.0, -128.0/255.0);
const vec3 matYUVRGB1 = vec3(1.0, 0.0, 1.402);
const vec3 matYUVRGB2 = vec3(1.0, -0.344, -0.714);
const vec3 matYUVRGB3 = vec3(1.0, 1.772, 0.0);

void main() {
    if (yuvType == 0) {// I420
        float y = texture(textureY, varyTextCoordinate).r;
        float u = texture(textureU, varyTextCoordinate).r - 0.5;
        float v = texture(textureV, varyTextCoordinate).r - 0.5;

        // yuv to rgb
        float r = y + 1.402 *v;
        float g = y - 0.344 *u - 0.714 *v;
        float b = y + 1.772 *u;

        fragColor = vec4(r, g, b, 1.0);
    } else {// NV12
        vec3 result;
        highp vec3 yuv;
        yuv.x = texture(texture_Y, varyTextCoordinate).r;
        yuv.y = texture(texture_UV, varyTextCoordinate).r;
        yuv.z = texture(texture_UV, varyTextCoordinate).a;
        
        yuv += delyuv;
        result.x = dot(yuv, matYUVRGB1);
        result.y = dot(yuv, matYUVRGB2);
        result.z = dot(yuv, matYUVRGB3);
        
        fragColor = vec4(result.rgb, 1);
    }
}
