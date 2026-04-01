#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec3 aColor;

out vec2 TexCoord;
out vec3 FragPos;
out vec3 Normal;
out vec3 Color;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;
uniform mat3 normMatrix;

void main()
{
    gl_Position = projection * view * model * vec4(aPos, 1.0f);
    TexCoord = aTexCoord;
    Normal = normMatrix * aNormal;
    Color =  aColor;
    FragPos = vec3(model * vec4(aPos, 1.0));
}
