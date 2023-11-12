Shader "Ogxd/Grid"
{
   Properties
   {
      _Color("Main Color", Color) = (0.5, 1.0, 1.0)
      _SecondaryColor("Secondary Color", Color) = (0.0, 0.0, 0.0)
      _BackgroundColor("Background Color", Color) = (0.0, 0.0, 0.0, 0.0)
      _MaskTexture("Texture", 2D) = "white" {}

      [Header(Grid)]
      _Scale("Scale", Float) = 1.0
      _GraduationScale("Graduation Scale", Float) = 1.0
      _Thickness("Lines Thickness", Range(0.0001, 0.01)) = 0.005
      _SecondaryFadeInSpeed("Secondary Fade In Speed", Range(0.1, 4)) = 0.5
   }
   SubShader
   {
      Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
      LOD 100

      ZWrite On // We need to write in depth to avoid tearing issues
      Blend SrcAlpha OneMinusSrcAlpha

      Pass
      {
         CGPROGRAM
         #pragma vertex vert
         #pragma fragment frag
         #pragma multi_compile _ UNITY_SINGLE_PASS_STEREO STEREO_INSTANCING_ON STEREO_MULTIVIEW_ON
         #include "UnityCG.cginc"

         struct appdata
         {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;
            UNITY_VERTEX_INPUT_INSTANCE_ID
         };

         struct v2f
         {
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;
            float4 vertex : SV_POSITION;
            UNITY_VERTEX_OUTPUT_STEREO
         };

         sampler2D _MaskTexture;
         float4 _MaskTexture_ST;

         float _Scale;
         float _GraduationScale;

         float _Thickness;
         float _SecondaryFadeInSpeed;

         fixed4 _Color;
         fixed4 _SecondaryColor;
         fixed4 _BackgroundColor;

         v2f vert (appdata v)
         {
            v2f o;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            o.vertex = UnityObjectToClipPos(v.vertex);

            // Remap UVs from [0:1] to [-0.5:0.5] to make scaling effect start from the center 
            o.uv = v.uv - 0.5f;
            // Scale the whole thing if necessary
            o.uv *= _GraduationScale;

            // UVs for mask texture
            o.uv1 = TRANSFORM_TEX(v.uv1, _MaskTexture);
            return o;
         }

         // Remap value from a range to another
         float remap(float value, float from1, float to1, float from2, float to2) {
            return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
         }

         // Apply the calculated scale
         float applyScale(float base, float scale) {
            return floor(frac((base - 0.5 * _Thickness) * scale) + _Thickness * scale);
         }

         fixed4 frag (v2f i) : SV_Target
         {
            fixed4 col;
            fixed4 maskCol = tex2D(_MaskTexture, i.uv1);
				
            // With the ceil value of the log10 of the scale, we obtain the closest measure unit above (eg : 165 -> 3, 0.146 -> 0, 0.001 -> -3)
            // Then, we do 10^(this value) to get the actual value of that unit in meters
            // Finally, we divide the scale by this unit in meters to have our log mapped scale
            // This way, we are sure our logMappedScale is between 0.1 and 1
            float logMappedScale = _Scale / pow(10, ceil(log10(_Scale)));

            // We want a zoom in effect when the users is scaling up his model.
            // Scaling up in 3D space means a lower scale value, so we have to use the invert the scale for our zoom effect.
            float localScale = 1 / logMappedScale;

            // Fade is used to make secondary grid appear slowly instead of popping
            // Here we remap the value from logMappedScale from [0.1:1] to [0:1]
            // The power can be used to make the fade effect faster or slower
            float fade =  pow(1 - remap(logMappedScale, 0.1, 1, 0.00001, 0.99999), _SecondaryFadeInSpeed);

            float2 pos;

            pos.x = applyScale(i.uv.x, localScale);
            pos.y = applyScale(i.uv.y, localScale);

            if (pos.x == 1 || pos.y == 1) {
               col = _Color;
               col.a = max((1 - fade), fade);
            } else {
               pos.x = applyScale(i.uv.x, 10.0 * localScale);
               pos.y = applyScale(i.uv.y, 10.0 * localScale);

               if (pos.x == 1 || pos.y == 1) {
                  col = _SecondaryColor;
                  col.a = (1 - fade);
               } else {
                  col = _BackgroundColor;
               }
            }
				
            // Apply mask multiplying by its alpha
            col.a *= maskCol.a;
            return col;
         }

         ENDCG
      }
   }
}