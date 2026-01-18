#version 460

uniform mat4 m_model;
uniform mat4 m_pv;

in vec4 position; 

void main() {
    // Simples e direto: Calcula a posição do vértice no ecrã.
    // Ignoramos o ID (position.w) porque não há animação.
    gl_Position = m_pv * m_model * vec4(position.xyz, 1.0);
}