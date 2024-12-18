//
// sdPlanarReflection
// 鏡像MME
//
// 針金P氏WorkingFloorAL ver0.0.7を参考に作成させていただきました
////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
#include "../../shader/sdPBRconfig.fxsub"
#include "../../shader/sdPBRcommon.fxsub"
#include "../../shader/sdPBRGBuffer.fxsub"

////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldMatrix     : WORLD;
float4x4 InvWorldMatrix     : WORLDINVERSE;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjectionMatrix      : PROJECTION;
float4x4 ViewProjectionMatrix  : VIEWPROJECTION;

//カメラ位置
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

//アクセサリの設定値

// 透過値
float _AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float _AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

//コントローラの設定値
#define CONT "sdPlanarReflection_ステージ用.pmx"
bool IsPMX : CONTROLOBJECT < string name = CONT; >;
float4x4 _CenterBoneMatrix : CONTROLOBJECT < string name = CONT; string item = "センター";>;
float _Transparency : CONTROLOBJECT < string name = CONT; string item = "透明度";>;
float _Blur : CONTROLOBJECT < string name = CONT; string item = "ボケ効果";>;
float _Displacement : CONTROLOBJECT < string name = CONT; string item = "歪み効果";>;
float _MaterialReflectance : CONTROLOBJECT < string name = CONT; string item = "下地";>;

//コントローラがあればその設定。ないならアクセの設定
static float4x4 CenterMatrix = IsPMX ? _CenterBoneMatrix : WorldMatrix;
static float AcsTr = IsPMX ? saturate(1-_Transparency) : _AcsTr;
static float Blur = IsPMX ? lerp(0,10,_Blur) : 10;
static float Displacement = IsPMX ? _Displacement : 1;
static float MaterialReflectance = IsPMX ? _MaterialReflectance : 1;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;

#define FORWARD_RENDERING
#include "../../shader/sdPBRShadingFunction.fxsub"

/*
//共有デプスバッファ(sdPRefに割り当てられた鏡像を描くためのシェーダから参照される)
//ここまでやるのは面倒くさいので一旦停止しとく
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

//AL発光体の所在マップ
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

// 床面鏡像描画のオフスクリーンバッファ
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
//床面鏡像描画

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

    // カメラ視点のビュー射影変換
    Pos = mul( Pos, ViewProjectionMatrix );

    Out.Pos = Pos;
    Out.SPos = Pos;
    Out.Normal = normalize(mul(Normal, (float3x3)WorldMatrix));

    return Out;
}

float2 PosToUV(float3 pos)
{
    float4 spos = mul(float4(pos,1), ViewProjectionMatrix);
    float2 suv = spos.xy / spos.w;  //スクリーン座標を元にしてシャドウマップのUVを求める
    suv.y = -suv.y;
    suv = (suv+1)/2 + 0.5/ViewportSize; //ViewportOffsetを足す
    return suv;
}


float3 Fresnel(int ShadingModelID, Material m, float NdotV)
{
    float3 f0;
    f0 = lerp(m.specular * 0.08, m.baseColor, m.metallic);
    //roughnessの低い物体でもテカりすぎるのを調整(Sebastien Lagarde氏の方法)
    float3 f = f0 + (max(1-m.roughness,f0)-f0) * pow(1.0 - NdotV, 5.0); 
    
    if (ShadingModelID == SMID_IRIDESCENCE) {
        float3 iri = FetchAtlas(LUT_IRIDESCENCE,float2(NdotV,m.iridescenceD));
        f = f * (1 - dot(iri, float3(0.3, 0.6, 0.1))) + iri;
    } else if (ShadingModelID == SMID_COSMETICS) {
        f *= lerp((1-m.porouscoat),1,m.clearcoat); //cosmeticsでのスペキュラの増減を適当に入れる
    }
    return f;
}

float3 CalcSpecular(int ShadingModelID, Material m, float NdotV)
{
    float3 f = Fresnel(ShadingModelID, m, NdotV);  //F項
    float2 BRDF = FetchAtlas(LUT_BRDF, float2(NdotV, m.roughness));
    return (f * BRDF.x + BRDF.y);  //F,G,D項の積分
}


float4 PS_Mirror(VS_OUTPUT IN, int2 vpos : VPOS) : COLOR
{
    //Gバッファ上でのuv
    float2 guv = vpos / ViewportSize + ViewportOffset;
    float3 n;
    float depth, alpha;
    int smid;

    //G-Bufferから材質を取る
    Material m = GetFrontMaterialFromGBuffer(guv, smid, n, depth, alpha);
    if (depth == 0 || MaterialReflectance == 0) {
        //G-Bufferに何も書いてないなら定義済みの材質を貼る
        m = (Material)0;
        m.baseColor = 1;
        m.metallic = 1;
        smid = SMID_STANDARD;
        n = IN.Normal;
        depth = length(CameraPosition - IN.WPos);
    }

    //鏡のY軸を基準にした鏡の接空間(Z+ = 鏡のY軸,アクセの場合スケール要素が入ってるので正規化する)
    float3x3 TBN = {normalize(CenterMatrix._11_12_13),normalize(CenterMatrix._31_32_33), normalize(CenterMatrix._21_22_23)};  
    float3 slope = mul(TBN,n);  //接空間で見た法線
    slope.z = abs(slope.z) < 0.001 ? sign(slope.z) * 0.001 : slope.z;
    float2 duv = slope.xy/slope.z;
    float2 slopeAlpha = smoothstep(2,1,abs(duv));
    duv *= Displacement;

    // 鏡像のスクリーンの座標(左右反転しているので元に戻す)
    float2 texCoord = float2(0.5 - IN.SPos.xy/IN.SPos.w*0.5) + ViewportOffset;
    texCoord -= duv;

    // 鏡像の色
    float NdotV = abs(dot(n,normalize(CameraPosition - IN.WPos)));
    float3 prefilteredColor = pow(tex2Dlod(WorkingFloorView, float4(texCoord,0,m.roughness * Blur)),GAMMA);
    float3 kS = CalcSpecular(smid, m, NdotV);

    //Ver.3.30追加。AutoLiminous(元々sdPBRmain.fxsubでやっていたが、1フレーム遅れるのでこっちに移した)
    #ifdef APPLY_AUTOLUMINOUS_MATERIAL
        prefilteredColor += pow(tex2Dlod(WorkingFloorAL, float4(texCoord,0,m.roughness * Blur)),GAMMA) * AutoLuminousIntensity;
    #endif

    //スペキュラ分＝映り込み。スペキュラ分以外＝Diffuse分＝元から描いてあった色
    //金属の場合は反射率がカラーになるが幸い金属のDiffuseは0なので地の色は0扱いでヨシ
    //金属以外の場合は反射率は基本的に単色なのでαブレンドで近似してヨシ
    float4 Color = float4(prefilteredColor,1);
    Color.rgb = lerp(Color.rgb, Color.rgb*kS, m.metallic);
    Color.a = lerp(AcsTr*RGBtoY(kS), AcsTr, m.metallic);  //ブレンド自体はsRGBで行われるのでどうしても少し不自然にはなる
    
    //鏡に対して傾き過ぎている面に対しては薄める
    Color.a *= slopeAlpha.x*slopeAlpha.y;

    //反射率一定にするモーフ
    Color = lerp(float4(prefilteredColor,AcsTr), Color, MaterialReflectance);


    Color.rgb = pow(Color.rgb, 1/GAMMA);
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

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

//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }




