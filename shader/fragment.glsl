#version 330 core

struct matrl
{
    sampler2D mainTex;
    vec3 mainVec;

    vec3 ambVec;
    sampler2D diffTex;
    vec3 diffVec;

    sampler2D specTex;
    vec3 specVec;
    float shininess;
};

struct posLgt 
{
    vec3 position;
  
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

struct dirLgt
{
    vec3 direction;
  
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in vec3 FragPos;  

uniform vec3 object_color;

uniform bool flatShade;
uniform bool useFlatTex;

uniform bool useDiffTex;
uniform bool useSpecTex;
uniform bool useDirLight;

uniform vec3 camPos;

uniform float specularStrength;
uniform float specularExponent;

uniform matrl material;
uniform posLgt posLight;
uniform dirLgt dirLight;

void main()
{
    if(!flatShade)
    {
        vec3 diffuse, ambient, specular;

        //Normal, light, FragPos
        vec3 norm = normalize(Normal);
        vec3 lightDir;
        vec3 lightDiff;
        vec3 lightSpec;
        vec3 lightAmb;
        float lightDist;
        float lightAttenuation = 1.0f;
        if(!useDirLight)
        {
            lightDist = length(posLight.position - FragPos);
            lightDir = normalize(posLight.position - FragPos);
            lightAmb = posLight.ambient;
            lightDiff = posLight.diffuse;
            lightSpec = posLight.specular;
            lightAttenuation = 1.0 / 
            (
                posLight.constant + 
                posLight.linear * lightDist + 
                posLight.quadratic * lightDist * lightDist
            );
        }
        else 
        {
            lightDir = normalize(-dirLight.direction);
            lightAmb = dirLight.ambient;
            lightDiff = dirLight.diffuse;
            lightSpec = dirLight.specular;
        }

        float diff = max(dot(norm, lightDir), 0.0);
        
        //material
        vec3 objCol;
        if(useFlatTex) objCol = texture(material.mainTex, TexCoord).rgb;
        else objCol = material.mainVec;

        //TexCoord, useDiffTex
        if(useDiffTex)
        {
            vec3 diffTex = vec3(texture(material.diffTex, TexCoord));
            diffuse = diff * lightDiff * diffTex;
            ambient = lightAmb * diffTex;
        }
        else
        {
            ambient = lightAmb * objCol * material.ambVec;
            diffuse = diff * lightDiff * objCol * material.diffVec;
        }
        //camPos
        vec3 viewDir = normalize(camPos - FragPos);
        vec3 reflectDir = reflect(-lightDir, norm);
        float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
        //useSpecTex
        if(useSpecTex)
            specular = vec3(texture(material.specTex, TexCoord)) * spec * lightSpec;
        else 
            specular = spec * lightSpec * material.specVec;
    
        vec3 result = ambient + diffuse + specular;
        result *= lightAttenuation;
        
        //FragColor
        FragColor = vec4(result, 1.0);
    }
    else
    {
        //object_texture, useTex
        if(!useFlatTex) FragColor = vec4(material.mainVec, 1.0);
        else vec3 FragColor = texture(material.mainTex, TexCoord).rgb;
    }
}