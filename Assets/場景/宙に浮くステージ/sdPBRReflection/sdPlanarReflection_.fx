//
// sdPlanarReflection
// ����MME
//
// �j��P��WorkingFloorAL ver0.0.7���Q�l�ɍ쐬�����Ă��������܂���
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
#include "../../shader/sdPBRconfig.fxsub"
#include "../../shader/sdPBRcommon.fxsub"
#include "../../shader/sdPBRGBuffer.fxsub"

////////////////////////////////////////////////////////////////////////////////////////////////

// ���W�ϊ��s��
float4x4 WorldMatrix     : WORLD;
float4x4 InvWorldMatrix     : WORLDINVERSE;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjectionMatrix      : PROJECTION;
float4x4 ViewProjectionMatrix  : VIEWPROJECTION;

//�J�����ʒu
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

//�A�N�Z�T���̐ݒ�l

// ���ߒl
float _AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float _AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

//�R���g���[���̐ݒ�l
#define CONT "sdPlanarReflection_�X�e�[�W�p.pmx"
bool IsPMX : CONTROLOBJECT < string name = CONT; >;
float4x4 _CenterBoneMatrix : CONTROLOBJECT < string name = CONT; string item = "�Z���^�[";>;
float _Transparency : CONTROLOBJECT < string name = CONT; string item = "�����x";>;
float _Blur : CONTROLOBJECT < string name = CONT; string item = "�{�P����";>;
float _Displacement : CONTROLOBJECT < string name = CONT; string item = "�c�݌���";>;
float _MaterialReflectance : CONTROLOBJECT < string name = CONT; string item = "���n";>;

//�R���g���[��������΂��̐ݒ�B�Ȃ��Ȃ�A�N�Z�̐ݒ�
static float4x4 CenterMatrix = IsPMX ? _CenterBoneMatrix : WorldMatrix;
static float AcsTr = IsPMX ? saturate(1-_Transparency) : _AcsTr;
static float Blur = IsPMX ? lerp(0,10,_Blur) : 10;
static float Displacement = IsPMX ? _Displacement : 1;
static float MaterialReflectance = IsPMX ? _MaterialReflectance : 1;

// �X�N���[���T�C�Y
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;

#define FORWARD_RENDERING
#include "../../shader/sdPBRShadingFunction.fxsub"

/*
//���L�f�v�X�o�b�t�@(sdPRef�Ɋ��蓖�Ă�ꂽ������`�����߂̃V�F�[�_����Q�Ƃ����)
//�����܂ł��͖̂ʓ|�������̂ň�U��~���Ƃ�
shared texture sdPBRefZ : OFFSCREENRENDERTARGET <
	string Description = "DepthMap for sdPlanarReflection ";
	string Format = "R32F";
	float2 ViewPortRatio = { 1.0, 1.0 };
	float4 ClearColor = { 0,0,0, 1 };
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
		"self=hide;"
		//EXT_DEPTHMAP
		"*.* = ../../map/depth/sdPBRDepthMap_WorkingFloor.fx;";
> ;
*/

//AL�����̂̏��݃}�b�v
shared texture sdPRefAL : OFFSCREENRENDERTARGET <
    string Description = "AutoLuminous emission detector for sdPlanarReflection";
    float2 ViewPortRatio = 1;
    float4 ClearColor = 0;
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    int MipLevels = 1;
    string Format = "A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "* = ../../map/AL/sdPBR_AL_Object_WorkingFloor.fxsub;"
    ;
>;
sampler WorkingFloorAL = sampler_state {
    texture = <sdPRefAL>;
    MinFilter = ANISOTROPIC;    MagFilter = ANISOTROPIC;    MipFilter = LINEAR;
    MaxAnisotropy = MAX_ANISOTROPY;
    AddressU  = CLAMP;    AddressV = CLAMP;
};

// ���ʋ����`��̃I�t�X�N���[���o�b�t�@
shared texture sdPRef : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for sdPlanarReflection";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = 0;
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int MipLevels = 0;
    string Format = "A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "skyboxDisplay.pmx = ../../skybox/skyboxDisplay_WorkingFloor.fx;"
        "skyboxDisplay_sRGB.pmx = ../../skybox/skyboxDisplay_sRGB_WorkingFloor.fx;"
        "DayDynamicSkyboxDisplay.pmx = ../../skybox2/DayDynamicSkyboxDisplay_WorkingFloor.fx;"
        "NightDynamicSkyboxDisplay.pmx = ../../skybox2/NightDynamicSkyboxDisplay_WorkingFloor.fx;"
        "CloudSkyboxDisplay.pmx = ../../skybox3/CloudSkyboxDisplay_WorkingFloor.fx;"
        "DaySkyboxDisplay.pmx = ../../skybox3/DaySkyboxDisplay_WorkingFloor.fx;"
        "* = ../../wf_material/bg/sdPBR_drywood.fx;"
    ;
>;
sampler WorkingFloorView = sampler_state {
    texture = <sdPRef>;
    MinFilter = ANISOTROPIC;    MagFilter = ANISOTROPIC;    MipFilter = LINEAR;
    MaxAnisotropy = MAX_ANISOTROPY;
    AddressU  = CLAMP;    AddressV = CLAMP;
};







////////////////////////////////////////////////////////////////////////////////////////////////
//���ʋ����`��

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float3 WPos : TEXCOORD0;
    float4 SPos : TEXCOORD1;
    float3 Normal : TEXCOORD2;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION, float3 Normal : NORMAL)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Pos = mul( Pos, WorldMatrix );
    Out.WPos = Pos.xyz;

    // �J�������_�̃r���[�ˉe�ϊ�
    Pos = mul( Pos, ViewProjectionMatrix );

    Out.Pos = Pos;
    Out.SPos = Pos;
    Out.Normal = normalize(mul(Normal, (float3x3)WorldMatrix));

    return Out;
}

float2 PosToUV(float3 pos)
{
    float4 spos = mul(float4(pos,1), ViewProjectionMatrix);
    float2 suv = spos.xy / spos.w;  //�X�N���[�����W�����ɂ��ăV���h�E�}�b�v��UV�����߂�
    suv.y = -suv.y;
    suv = (suv+1)/2 + 0.5/ViewportSize; //ViewportOffset�𑫂�
    return suv;
}


float3 Fresnel(int ShadingModelID, Material m, float NdotV)
{
    float3 f0;
    f0 = lerp(m.specular * 0.08, m.baseColor, m.metallic);
    //roughness�̒Ⴂ���̂ł��e�J�肷����̂𒲐�(Sebastien Lagarde���̕��@)
    float3 f = f0 + (max(1-m.roughness,f0)-f0) * pow(1.0 - NdotV, 5.0); 
    
    if (ShadingModelID == SMID_IRIDESCENCE) {
        float3 iri = FetchAtlas(LUT_IRIDESCENCE,float2(NdotV,m.iridescenceD));
        f = f * (1 - dot(iri, float3(0.3, 0.6, 0.1))) + iri;
    } else if (ShadingModelID == SMID_COSMETICS) {
        f *= lerp((1-m.porouscoat),1,m.clearcoat); //cosmetics�ł̃X�y�L�����̑�����K���ɓ����
    }
    return f;
}

float3 CalcSpecular(int ShadingModelID, Material m, float NdotV)
{
    float3 f = Fresnel(ShadingModelID, m, NdotV);  //F��
    float2 BRDF = FetchAtlas(LUT_BRDF, float2(NdotV, m.roughness));
    return (f * BRDF.x + BRDF.y);  //F,G,D���̐ϕ�
}


float4 PS_Mirror(VS_OUTPUT IN, int2 vpos : VPOS) : COLOR
{
    //G�o�b�t�@��ł�uv
    float2 guv = vpos / ViewportSize + ViewportOffset;
    float3 n;
    float depth, alpha;
    int smid;

    //G-Buffer����ގ������
    Material m = GetFrontMaterialFromGBuffer(guv, smid, n, depth, alpha);
    if (depth == 0 || MaterialReflectance == 0) {
        //G-Buffer�ɉ��������ĂȂ��Ȃ��`�ς݂̍ގ���\��
        m = (Material)0;
        m.baseColor = 1;
        m.metallic = 1;
        smid = SMID_STANDARD;
        n = IN.Normal;
        depth = length(CameraPosition - IN.WPos);
    }

    //����Y������ɂ������̐ڋ��(Z+ = ����Y��,�A�N�Z�̏ꍇ�X�P�[���v�f�������Ă�̂Ő��K������)
    float3x3 TBN = {normalize(CenterMatrix._11_12_13),normalize(CenterMatrix._31_32_33), normalize(CenterMatrix._21_22_23)};  
    float3 slope = mul(TBN,n);  //�ڋ�ԂŌ����@��
    slope.z = abs(slope.z) < 0.001 ? sign(slope.z) * 0.001 : slope.z;
    float2 duv = slope.xy/slope.z;
    float2 slopeAlpha = smoothstep(2,1,abs(duv));
    duv *= Displacement;

    // �����̃X�N���[���̍��W(���E���]���Ă���̂Ō��ɖ߂�)
    float2 texCoord = float2(0.5 - IN.SPos.xy/IN.SPos.w*0.5) + ViewportOffset;
    texCoord -= duv;

    // �����̐F
    float NdotV = abs(dot(n,normalize(CameraPosition - IN.WPos)));
    float3 prefilteredColor = pow(tex2Dlod(WorkingFloorView, float4(texCoord,0,m.roughness * Blur)),GAMMA);
    float3 kS = CalcSpecular(smid, m, NdotV);

    //Ver.3.30�ǉ��BAutoLiminous(���XsdPBRmain.fxsub�ł���Ă������A1�t���[���x���̂ł������Ɉڂ���)
    #ifdef APPLY_AUTOLUMINOUS_MATERIAL
        prefilteredColor += pow(tex2Dlod(WorkingFloorAL, float4(texCoord,0,m.roughness * Blur)),GAMMA) * AutoLuminousIntensity;
    #endif

    //�X�y�L���������f�荞�݁B�X�y�L�������ȊO��Diffuse����������`���Ă������F
    //�����̏ꍇ�͔��˗����J���[�ɂȂ邪�K��������Diffuse��0�Ȃ̂Œn�̐F��0�����Ń��V
    //�����ȊO�̏ꍇ�͔��˗��͊�{�I�ɒP�F�Ȃ̂Ń��u�����h�ŋߎ����ă��V
    float4 Color = float4(prefilteredColor,1);
    Color.rgb = lerp(Color.rgb, Color.rgb*kS, m.metallic);
    Color.a = lerp(AcsTr*RGBtoY(kS), AcsTr, m.metallic);  //�u�����h���̂�sRGB�ōs����̂łǂ����Ă������s���R�ɂ͂Ȃ�
    
    //���ɑ΂��ČX���߂��Ă���ʂɑ΂��Ă͔��߂�
    Color.a *= slopeAlpha.x*slopeAlpha.y;

    //���˗����ɂ��郂�[�t
    Color = lerp(float4(prefilteredColor,AcsTr), Color, MaterialReflectance);


    Color.rgb = pow(Color.rgb, 1/GAMMA);
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//�e�N�j�b�N

technique MainTec0 < string MMDPass = "object"; > {
    pass DrawObject{
        SRGBWriteEnable = true;
        VertexShader = compile vs_3_0 VS_Mirror();
        PixelShader  = compile ps_3_0 PS_Mirror();
    }
}

technique MainTec1 < string MMDPass = "object_ss"; > {
    pass DrawObject{
        SRGBWriteEnable = true;
        VertexShader = compile vs_3_0 VS_Mirror();
        PixelShader  = compile ps_3_0 PS_Mirror();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////

//�e��֊s�͕`�悵�Ȃ�
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }




