#version 460

// REMOVIDO: in vec3 gNormal; (O Geometry Shader já não envia isto)

out vec4 outputColor;

void main() {
    // Cor Sólida (Verde Matrix para veres bem as linhas)
    // Podes mudar para vec4(1.0, 1.0, 1.0, 1.0) para branco
    outputColor = vec4(0.0, 1.0, 0.0, 1.0);
}