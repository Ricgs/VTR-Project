#version 460

layout(lines) in;
layout(line_strip, max_vertices = 2) out; 

uniform mat4 m_pv; // Projection * View

void main() {
    // Ponto 1
    gl_Position = m_pv * gl_in[0].gl_Position;
    EmitVertex();

    // Ponto 2
    gl_Position = m_pv * gl_in[1].gl_Position;
    EmitVertex();
    
    EndPrimitive();
}