#version 300 es
precision highp float;

layout (location = 0) in vec4 position;
layout (location = 1) in vec2 textCoordinate;
out vec2 varyTextCoordinate;

void main() {
    varyTextCoordinate = textCoordinate;
    gl_Position = position;
}
