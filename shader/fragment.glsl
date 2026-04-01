#version 330 core

//outs and ins

out vec4 FragColor;

in vec2 TexCoord;
in vec3 Normal;
in vec3 FragPos;  
in vec3 Color;

//lighting

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

struct flashLgt
{
    vec3 position;
    vec3 direction;
    float cutOff;
    float cutOff2;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

#define NR_POS_LIGHTS 4

uniform posLgt[NR_POS_LIGHTS] posLight;
uniform dirLgt dirLight;
uniform flashLgt flashLight;

//cube Rendering Settings

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

uniform vec3 object_color;

uniform bool flatShade;
uniform bool useFlatTex;

uniform bool useMainTex;
uniform bool useDiffTex;
uniform bool useSpecTex;

uniform vec3 camPos;

uniform float specularStrength;
uniform float specularExponent;

uniform matrl material;

vec3 CalcDirLight(dirLgt light, vec3 normal, vec3 viewDir);
vec3 CalcPointLight(posLgt light, vec3 normal, vec3 fragPos, vec3 viewDir);
vec3 CalcFlashLight(flashLgt light, vec3 normal, vec3 fragPos, vec3 viewDir);

//Assimp Render Settings
uniform bool assimp;

#define MAXTEX 12

uniform sampler2D asiTexture[MAXTEX];
uniform int       asiTexType[MAXTEX];
//uniform float     asiTexBlend[MAXTEX];
//uniform int       asiTexBlendOp[MAXTEX];
uniform int       asiNumOfTextures;

struct asiMatrl
{
    vec3 base;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float specularStrength;
    float specularExponent;
    
    float opacity;

    vec3 transparent;
    vec3 emmissive;
    float reflectivity;
    float shininess;
    float bumpScaling;
};

uniform asiMatrl asiMaterial;

vec3 asiCalcDirLight(dirLgt light, vec3 normal, vec3 viewDir);
vec3 asiCalcPointLight(posLgt light, vec3 normal, vec3 fragPos, vec3 viewDir);
vec3 asiCalcFlashLight(flashLgt light, vec3 normal, vec3 fragPos, vec3 viewDir);

void main()
{
    if(assimp)
    {
        vec3 diffuse, ambient, specular;
        vec3 norm = normalize(Normal);
        vec3 viewDir = normalize(camPos - FragPos);
        vec3 result = vec3(0);

        for(int i = 0; i < NR_POS_LIGHTS; i++)
        {
            if(posLight[i].constant == 0) continue;

            result += asiCalcPointLight(posLight[i], norm, FragPos, viewDir);
        }

        if(length(dirLight.diffuse) > 0.0 || length(dirLight.ambient) > 0.0) 
        {
            result += asiCalcDirLight(dirLight, norm, viewDir);
        }

        if(flashLight.constant != 0)
        result += asiCalcFlashLight(flashLight, norm, FragPos, viewDir);

        FragColor = vec4(result, 1.0);
        return;
    }
    else if(!flatShade)
    {
        vec3 diffuse, ambient, specular;

        //Normal, light, FragPos
        vec3 norm = normalize(Normal);

        vec3 viewDir = normalize(camPos - FragPos);
        
        vec3 result = vec3(0);

        for(int i = 0; i < NR_POS_LIGHTS; i++)
        {
            if(posLight[i].constant == 0) continue;

            result += CalcPointLight(posLight[i], norm, FragPos, viewDir);
        }

        // Inside fragment.glsl main()
        if(length(dirLight.diffuse) > 0.0 || length(dirLight.ambient) > 0.0) 
        {
            result += CalcDirLight(dirLight, norm, viewDir);
        }
        if(flashLight.constant != 0)
        result += CalcFlashLight(flashLight, norm, FragPos, viewDir);
        
        //FragColor
        FragColor = vec4(result, 1.0);
    }
    else
    {
        //object_texture, useTex
        if(!useFlatTex) FragColor = vec4(material.mainVec, 1.0);
        else FragColor = vec4(texture(material.mainTex, TexCoord).rgb, 1.0);
    }
}

//cube render functions-------------------------------------------------------------------------------

vec3 CalcDirLight(dirLgt light, vec3 normal, vec3 viewDir)
{
    vec3 lightDir = normalize(-light.direction);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // combine results

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol;
    if(useMainTex) objCol = vec3(texture(material.mainTex, TexCoord));
    else objCol = vec3(material.mainVec);

    if(useDiffTex)
        {
            vec3 diffTex = vec3(texture(material.diffTex, TexCoord));
            diffuse = diff * light.diffuse * diffTex;
            ambient = light.ambient * diffTex;
        }
        else
        {
            ambient = light.ambient * objCol * material.ambVec;
            diffuse = diff * light.diffuse * objCol * material.diffVec;
        }
    if(useSpecTex)
            specular = vec3(texture(material.specTex, TexCoord)) * spec * light.specular;
        else 
            specular = spec * light.specular * material.specVec;

    return (ambient + diffuse + specular);
}

vec3 CalcPointLight(posLgt light, vec3 normal, vec3 fragPos, vec3 viewDir)
{
    vec3 lightDir = normalize(light.position - fragPos);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // combine results
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol;
    if(useMainTex) objCol = vec3(texture(material.mainTex, TexCoord));
    else objCol = vec3(material.mainVec);

    if(useDiffTex)
        {
            vec3 diffTex = vec3(texture(material.diffTex, TexCoord));
            diffuse = diff * light.diffuse * diffTex;
            ambient = light.ambient * diffTex;
        }
        else
        {
            ambient = light.ambient * objCol * material.ambVec;
            diffuse = diff * light.diffuse * objCol * material.diffVec;
        }
    if(useSpecTex)
            specular = vec3(texture(material.specTex, TexCoord)) * spec * light.specular;
        else 
            specular = spec * light.specular * material.specVec;

    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;
    return (ambient + diffuse + specular);
}

vec3 CalcFlashLight(flashLgt light, vec3 normal, vec3 fragPos, vec3 viewDir)
{
    vec3 lightDir = normalize(light.position - fragPos);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // spotlight intensity
    float theta = dot(lightDir, normalize(-light.direction)); 
    float epsilon = light.cutOff - light.cutOff2;
    float intensity = clamp((theta - light.cutOff2) / epsilon, 0.0, 3.5);
    // combine results
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol;
    if(useMainTex) objCol = vec3(texture(material.mainTex, TexCoord));
    else objCol = vec3(material.mainVec);

    if(useDiffTex)
        {
            vec3 diffTex = vec3(texture(material.diffTex, TexCoord));
            diffuse = diff * light.diffuse * diffTex;
            ambient = light.ambient * diffTex;
        }
        else
        {
            ambient = light.ambient * objCol * material.ambVec;
            diffuse = diff * light.diffuse * objCol * material.diffVec;
        }
    if(useSpecTex)
            specular = vec3(texture(material.specTex, TexCoord)) * spec * light.specular;
        else 
            specular = spec * light.specular * material.specVec;

    ambient *= attenuation * intensity;
    diffuse *= attenuation * intensity;
    specular *= attenuation * intensity;
    return (ambient + diffuse + specular);
}

//asi render functions-------------------------------------------------------------------------------

vec3 asiCalcDirLight(dirLgt light, vec3 normal, vec3 viewDir)
{
    vec3 lightDir = normalize(-light.direction);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), asiMaterial.specularExponent);
    // combine results

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol = asiMaterial.base;
    
    vec4 finalDiffuse = vec4(1.0);
    bool isFirstDiffuse = true;

    vec3 finalSpecular = vec3(1);
    bool isFirstSpecular = true;

    for(int i = 0; i < asiNumOfTextures; i++) {
        
        if (asiTexType[i] == 1) 
        { // TYPE_DIFFUSE
            vec4 texColor = texture(asiTexture[i], TexCoord);
            //float weight = asiTexBlend[i]; // Grab the weight
            //int op = asiTexBlendOp[i];

            if (isFirstDiffuse) 
            {
                // If the base texture has a weight less than 1.0, it fades into the object's baseColor
                finalDiffuse = texColor;// * weight; 
                isFirstDiffuse = false;
                
            } 
            else 
            {
                if (texColor.a < 1.0) 
                {
    // 1. If it has transparent pixels, the artist almost certainly wants a Mix (Decal)
                    finalDiffuse = mix(finalDiffuse, texColor, texColor.a/* * weight */);
                } 
                else 
                {
    // 2. If it is fully solid, respect the Assimp Math Operation
                    finalDiffuse *= (texColor/* * weight */);
                }
            }
        }
        
        else if (asiTexType[i] == 2) 
        {
            //int op = asiTexBlendOp[i];
            // Specular is usually grayscale, so we only need the RGB
            vec3 specColor = texture(asiTexture[i], TexCoord).rgb;
            //float weight = asiTexBlend[i];

            if (isFirstSpecular) 
            {
                // First map establishes the base shininess map
                finalSpecular = specColor;// * weight;
                isFirstSpecular = false;
            } 
            else 
            {
                // Mix them based on the artist's Blend Factor (weight)
                // mix(A, B, 0.5) perfectly averages them
                //if(weight != 1.0f) finalSpecular = mix(finalSpecular, specColor, weight);
                //else 
                finalSpecular *= (specColor/* * weight */);
            }
        }
    }

    diffuse = vec3(finalDiffuse) * diff * light.diffuse * asiMaterial.diffuse * Color;
    ambient = vec3(finalDiffuse) * light.ambient * asiMaterial.ambient * Color;
    specular = finalSpecular * spec * light.specular * asiMaterial.specular * asiMaterial.specularStrength;

    return (ambient + diffuse + specular);
}

vec3 asiCalcPointLight(posLgt light, vec3 normal, vec3 fragPos, vec3 viewDir)
{
    vec3 lightDir = normalize(light.position - fragPos);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // combine results
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol = asiMaterial.base;
    
    vec4 finalDiffuse = vec4(1.0);
    bool isFirstDiffuse = true;

    vec3 finalSpecular = vec3(1);
    bool isFirstSpecular = true;

    for(int i = 0; i < asiNumOfTextures; i++) {
        
        if (asiTexType[i] == 1 || asiTexType[i] == 12) 
        { // TYPE_DIFFUSE
            vec4 texColor = texture(asiTexture[i], TexCoord);
            //float weight = asiTexBlend[i]; // Grab the weight
            //int op = asiTexBlendOp[i];

            if (isFirstDiffuse) 
            {
                // If the base texture has a weight less than 1.0, it fades into the object's baseColor
                finalDiffuse = texColor;// * weight; 
                isFirstDiffuse = false;
                
            } 
            else 
            {
                //if (texColor.a < 1.0) 
                //{
    // 1. If it has transparent pixels, the artist almost certainly wants a Mix (Decal)
                    //finalDiffuse = mix(finalDiffuse, texColor, texColor.a * weight);
                //} 
                //else 
                {
    // 2. If it is fully solid, respect the Assimp Math Operation
                    finalDiffuse *= (texColor/* * weight */);
                }
            }
        }
        
        else if (asiTexType[i] == 2) 
        {
            //int op = asiTexBlendOp[i];
            // Specular is usually grayscale, so we only need the RGB
            vec3 specColor = texture(asiTexture[i], TexCoord).rgb;
            //float weight = asiTexBlend[i];

            if (isFirstSpecular) 
            {
                // First map establishes the base shininess map
                finalSpecular = specColor;// * weight;
                isFirstSpecular = false;
            } 
            else 
            {
                // Mix them based on the artist's Blend Factor (weight)
                // mix(A, B, 0.5) perfectly averages them
                //if(weight != 1.0f) finalSpecular = mix(finalSpecular, specColor, weight);
                //else 
                finalSpecular *= (specColor/* * weight */);
            }
        }
    }

    diffuse = vec3(finalDiffuse) * diff * light.diffuse * asiMaterial.diffuse * Color;
    ambient = vec3(finalDiffuse) * light.ambient * asiMaterial.ambient * Color;
    specular = finalSpecular * spec * light.specular * asiMaterial.specular * asiMaterial.specularStrength;

    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;
    return (ambient + diffuse + specular);
}

vec3 asiCalcFlashLight(flashLgt light, vec3 normal, vec3 fragPos, vec3 viewDir)
{
    vec3 lightDir = normalize(light.position - fragPos);
    // diffuse shading
    float diff = max(dot(normal, lightDir), 0.0);
    // specular shading
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), asiMaterial.specularExponent);
    // attenuation
    float distance = length(light.position - fragPos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // spotlight intensity
    float theta = dot(lightDir, normalize(-light.direction)); 
    float epsilon = light.cutOff - light.cutOff2;
    float intensity = clamp((theta - light.cutOff2) / epsilon, 0.0, 3.5);
    // combine results
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    vec3 objCol = asiMaterial.base;
    
    vec4 finalDiffuse = vec4(1.0);
    bool isFirstDiffuse = true;

    vec3 finalSpecular = vec3(1);
    bool isFirstSpecular = true;

    for(int i = 0; i < asiNumOfTextures; i++) {
        
        if (asiTexType[i] == 1) 
        { // TYPE_DIFFUSE
            vec4 texColor = texture(asiTexture[i], TexCoord);
            //float weight = asiTexBlend[i]; // Grab the weight
            //int op = asiTexBlendOp[i];

            if (isFirstDiffuse) 
            {
                // If the base texture has a weight less than 1.0, it fades into the object's baseColor
                finalDiffuse = texColor;// * weight; 
                isFirstDiffuse = false;
                
            } 
            else 
            {
                //if (texColor.a < 1.0) 
                //{
    // 1. If it has transparent pixels, the artist almost certainly wants a Mix (Decal)
                    //finalDiffuse = mix(finalDiffuse, texColor, texColor.a * weight);
                //} 
                //else 
                {
    // 2. If it is fully solid, respect the Assimp Math Operation
                    finalDiffuse *= (texColor/* * weight */);
                }
            }
        }
        
        else if (asiTexType[i] == 2) 
        {
            //int op = asiTexBlendOp[i];
            // Specular is usually grayscale, so we only need the RGB
            vec3 specColor = texture(asiTexture[i], TexCoord).rgb;
            //float weight = asiTexBlend[i];

            if (isFirstSpecular) 
            {
                // First map establishes the base shininess map
                finalSpecular = specColor;// * weight;
                isFirstSpecular = false;
            } 
            else 
            {
                // Mix them based on the artist's Blend Factor (weight)
                // mix(A, B, 0.5) perfectly averages them
                //if(weight != 1.0f) finalSpecular = mix(finalSpecular, specColor, weight);
                //else 
                finalSpecular *= (specColor/* * weight */);
            }
        }
    }

    diffuse = vec3(finalDiffuse) * diff * light.diffuse * asiMaterial.diffuse * Color;
    ambient = vec3(finalDiffuse) * light.ambient * asiMaterial.ambient * Color;
    specular = finalSpecular * spec * light.specular * asiMaterial.specular * asiMaterial.specularStrength;

    ambient *= attenuation * intensity;
    diffuse *= attenuation * intensity;
    specular *= attenuation * intensity;
    return (ambient + diffuse + specular);
}