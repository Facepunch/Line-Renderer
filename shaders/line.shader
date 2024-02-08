HEADER
{
	Description = "Line Shader for S&box";
}

FEATURES
{
	#include "common/features.hlsl"
}

MODES
{
	VrForward();
	Depth( S_MODE_DEPTH );
	ToolsVis( S_MODE_TOOLS_VIS );
}

COMMON
{
	#include "common/shared.hlsl"

	static const int Cap_None			= 0;
	static const int Cap_Triangle		= 1;
	static const int Cap_Arrow			= 2;
	static const int Cap_Rounded		= 3;

	int StartCap < Attribute( "StartCap" ); Default( 0 );  >;
	int EndCap < Attribute( "EndCap" ); Default( 0 );  >;
	int Smoothness < Attribute( "Smoothness" ); Default( 1 ); >;

}

struct VS_INPUT
{
	float3 pos : POSITION < Semantic( None ); >;
	float4 uv  : TEXCOORD0 < Semantic( None ); >;
    float4 normal : NORMAL < Semantic( None ); >;
    float4 velocity : TANGENT0 < Semantic( None ); >;
    float4 tint : TEXCOORD1 < Semantic( None ); >;
    float4 color : COLOR0 < Semantic( None ); >;

};

struct GS_INPUT
{
    float3 pos : POSITION;
    float4 uv : TEXCOORD0;
    float4 normal : NORMAL;
    float4 velocity : TANGENT0;
    float4 tint : COLOR0;
    float4 color : COLOR1;
};

struct PS_INPUT
{
	float4 vPositionPs : SV_ScreenPosition;
    float3 worldpos: TEXCOORD1;
	float4 tint : TEXCOORD9;
	float4 sheetUv : TEXCOORD3;
};

VS
{
	GS_INPUT MainVs(const VS_INPUT i)
	{
		return i;
	}
}

GS
{

	void CalculateCorners( float width, GS_INPUT prev, GS_INPUT cur, GS_INPUT next, out PS_INPUT ca, out PS_INPUT cb )
	{
		// direction from the join to the camera
		float3 normal = normalize( cur.pos - g_vCameraPositionWs );

		// the two line vectors
		float3 coming = prev.pos - cur.pos;
		float3 going = cur.pos - next.pos;

		// subtract the camera direction from line directions
		// because we're not interested in that when facing the camera
		coming -= normal * dot(coming, normal);
		going -= normal * dot(going, normal);

		// detect sharp, ugly angles
		if ( dot( normalize(coming), normalize(going)) < -0.85 )
		{
			// do something?
		}
		
		// average out the two line directions
		float3 average = normalize( normalize(coming) + normalize(going) );

		//average -= normal * dot(average, normal);

		// work out the tangent from that averaged line	
		float3 tangent = cross( average, normal );

		// init
		ca.sheetUv = 0;
		ca.tint = cur.tint;
		cb = ca;

		// position is current position offset by the tangent
		ca.worldpos = cur.pos + tangent * width;
		cb.worldpos = cur.pos - tangent * width;

		ca.vPositionPs = Position3WsToPs( ca.worldpos );
		cb.vPositionPs = Position3WsToPs( cb.worldpos );

		//cb = ScreenSpaceToWorldSpace( ss_cur ).xyz + g_vCameraPositionWs.xyz;
	}

	void AddEndCap( int mode, in PS_INPUT a, in PS_INPUT b, float3 delta, inout TriangleStream<PS_INPUT> output )
	{
		delta = normalize( delta );
		float3 tangent = b.worldpos - a.worldpos;
		float3 len = length( tangent );
		float3 cp = a.worldpos + tangent * 0.5;

		if ( mode == Cap_Triangle)
		{
			PS_INPUT o = a;
			o.worldpos = cp + delta * len;
			o.vPositionPs = Position3WsToPs( o.worldpos );

			output.Append(a);
			output.Append(b);
			output.Append(o);
			GSRestartStrip(output);
		}

		if ( mode == Cap_Arrow)
		{
			PS_INPUT o = a;
			o.worldpos = cp + delta * len * 2;
			o.vPositionPs = Position3WsToPs( o.worldpos );

			a.worldpos -= tangent;
			a.vPositionPs = Position3WsToPs( a.worldpos );

			b.worldpos += tangent;
			b.vPositionPs = Position3WsToPs( b.worldpos );

			output.Append(a);
			output.Append(b);
			output.Append(o);
			GSRestartStrip(output);
		}

		if ( mode == Cap_Rounded)
		{
			float3 pp = a.worldpos;
			float segments = 6;

			for ( float s = 0; s< segments; s++ )
			{
				float ang = (s / segments) * M_PI + M_PI * -0.5;

				PS_INPUT o = a;
				o.worldpos = cp + (tangent * 0.5 * sin(ang)) + (delta * len * cos(ang) );
				o.vPositionPs = Position3WsToPs( o.worldpos );

				a.worldpos = pp;
				a.vPositionPs = Position3WsToPs( a.worldpos );

				output.Append(a);
				output.Append(b);
				output.Append(o);
				GSRestartStrip(output);

				pp = o.worldpos;
			}
		}
	}

	void DrawLine( GS_INPUT i[4], inout TriangleStream<PS_INPUT> output )
	{
		PS_INPUT a;
		PS_INPUT b;
		PS_INPUT c;
		PS_INPUT d;

		float3 lineDelta = i[1].pos - i[2].pos;
		bool startCap = false;
		bool endCap = false;

		if ( length( i[0].pos - i[1].pos ) < 0.01 )
		{
			i[0].pos += normalize( lineDelta );
			startCap = true;
		}

		if ( length( i[2].pos - i[3].pos ) < 0.01 )
		{
			i[3].pos += normalize( -lineDelta );
			endCap = true;
		}

		CalculateCorners( i[1].uv.x, i[0], i[1], i[2], a, b );
		CalculateCorners( i[2].uv.x, i[1], i[2], i[3], c, d );

		output.Append(a);
		output.Append(c);
		output.Append(b);
		output.Append(d);

		GSRestartStrip(output);

		if ( startCap )
		{
			AddEndCap( StartCap, a, b, lineDelta, output );
		}

		if ( endCap )
		{
			AddEndCap( EndCap, c, d, -lineDelta, output );
		}
	}

	float3 CatmullRom(float3 p0, float3 p1, float3 p2, float3 p3, float t) 
	{
		float t2 = t * t;
		float t3 = t2 * t;

		float3 v0 = (p2 - p0) * 0.5;
		float3 v1 = (p3 - p1) * 0.5;
		float3 p = (2 * p1 - 2 * p2 + v0 + v1) * t3 + (-3 * p1 + 3 * p2 - 2 * v0 - v1) * t2 + v0 * t + p1;

		return p;
	}

	#define SMOOTH_STEPS 14

	[maxvertexcount(64)]
	void MainGs(lineadj GS_INPUT i[4], inout TriangleStream<PS_INPUT> output)
	{	
		if ( Smoothness <= 1 )
		{
			DrawLine ( i, output );
			return;
		} 

		GS_INPUT points[SMOOTH_STEPS];

		for ( int s = 0; s<SMOOTH_STEPS; s++ )
		{
			float delta = s / (SMOOTH_STEPS-1.0);

			points[s] = i[1];

			if ( delta > 0.5 ) points[s] = i[2];

			points[s].pos = CatmullRom( i[0].pos, i[1].pos, i[2].pos, i[3].pos, delta );
			points[s].uv = lerp( i[1].uv, i[2].uv, delta );
			points[s].tint = lerp( i[1].tint, i[2].tint, delta );
		}

		// Agh! need to stitch these together!
		points[0] = i[0];
		points[1] = i[1];
		points[SMOOTH_STEPS-2] = i[2];
		points[SMOOTH_STEPS-1] = i[3];

		GS_INPUT set[4];
		for ( int j = 1; j<SMOOTH_STEPS-2; j++ )
		{
			set[0] = points[j-1];
			set[1] = points[j+0];
			set[2] = points[j+1];
			set[3] = points[j+2];

			DrawLine( set, output );
		}
	}


}

PS
{
	#define CUSTOM_MATERIAL_INPUTS 1
	#include "common/pixel.hlsl"

	StaticCombo( S_MODE_DEPTH, 0..1, Sys( ALL ) );
	DynamicCombo( D_BLEND, 0..1, Sys( ALL ) );
	DynamicCombo( D_OPAQUE, 0..1, Sys( ALL ) );
	DynamicCombo( D_WIREFRAME, 0..1, Sys( ALL ) );

	float g_DepthFeather < Attribute( "g_DepthFeather" ); >;
	float g_FogStrength < Attribute( "g_FogStrength" ); >;

	SamplerState g_sParticleTrilinearWrap < Filter( MIN_MAG_MIP_LINEAR ); MaxAniso( 1 ); >;

	CreateTexture2D( g_ColorTexture ) < Attribute( "BaseTexture" ); Filter( BILINEAR ); AddressU( CLAMP ); AddressV( CLAMP ); AddressW( CLAMP ); SrgbRead( true ); >;
	float4 g_SheetData < Attribute( "BaseTextureSheet" ); >;

	RenderState( DepthWriteEnable, true );
	RenderState( CullMode, NONE );

	// additive
	#if ( D_BLEND == 1 ) 
		RenderState( BlendEnable, true );
		RenderState( SrcBlend, SRC_ALPHA );
		RenderState( DstBlend, ONE );
		RenderState( DepthWriteEnable, false );
	#else 
		RenderState( BlendEnable, true );
		RenderState( SrcBlend, SRC_ALPHA );
		RenderState( DstBlend, INV_SRC_ALPHA );
		RenderState( BlendOp, ADD );
		RenderState( SrcBlendAlpha, ONE );
		RenderState( DstBlendAlpha, INV_SRC_ALPHA );
		RenderState( BlendOpAlpha, ADD );
	#endif

	#if S_MODE_DEPTH == 0
		RenderState( DepthWriteEnable, false );
	#endif

	#if D_OPAQUE == 1
		RenderState( DepthWriteEnable, true );
		RenderState( BlendEnable, false );
	#endif

	#if D_WIREFRAME
		RenderState( FillMode, WIREFRAME );
	#endif

	float4 MainPs( PS_INPUT i ) : SV_Target0
	{
		float4 col = Tex2D( g_ColorTexture, i.sheetUv.xy );

		col.rgba *= i.tint.rgba;
	
		if ( g_DepthFeather > 0 )
		{
			float3 pos = Depth::GetWorldPosition( i.vPositionPs.xy );

			float dist = distance( pos, i.worldpos.xyz );
			float feather = clamp(dist / g_DepthFeather, 0.0, 1.0 );
			col.a *= feather;
		}

	    clip(col.a - 0.0001);

		#if D_OPAQUE
			OpaqueFadeDepth( pow( col.a, 0.5f ), i.vPositionPs.xy );
		#endif

		#if S_MODE_DEPTH
			OpaqueFadeDepth( pow( col.a, 0.3f ), i.vPositionPs.xy );
			return 1;
		#elif (D_BLEND == 1)
			// transparency
		#else
						
		#endif
	
		if ( g_FogStrength > 0 )
		{
			float3 fogged = Fog::Apply( i.worldpos, i.vPositionPs.xy, col.rgb );
			col.rgb = lerp( col.rgb, fogged, g_FogStrength );
		}

		return col;
	}
}
