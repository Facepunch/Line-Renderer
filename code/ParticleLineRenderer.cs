

namespace Sandbox;

[Title( "Line Renderer" )]
[Category( "Particles" )]
[Icon( "favorite" )]
public sealed class ParticleLineRenderer : Component, Component.ExecuteInEditor
{
	SceneDynamicObject _so;
	[Property] public Texture Texture { get; set; } = Texture.White;
	[Property, Range( 0, 50 )] public float DepthFeather { get; set; } = 0.0f;
	[Property, Range( 0, 1 )] public float FogStrength { get; set; } = 1.0f;
	[Property, Range( 0, 2 )] public float Scale { get; set; } = 1.0f;
	[Property] public bool Additive { get; set; }
	[Property] public bool Shadows { get; set; }
	[Property] public bool Opaque { get; set; }



	protected override void OnEnabled()
	{
		_so = new SceneDynamicObject( Scene.SceneWorld );
		_so.Transform = Transform.World;
	}

	protected override void OnDisabled()
	{
		_so?.Delete();
		_so = null;
	}


	protected override void OnPreRender()
	{
		if ( _so is null ) return;
		if ( !Components.TryGet( out ParticleEffect effect ) || effect.Particles.Count == 0 )
		{
			_so.RenderingEnabled = false;
			_so.Clear();
			return;
		}

		var viewerPosition = Scene.Camera?.Transform.Position ?? Vector3.Zero;

		_so.RenderingEnabled = true;
		_so.Transform = Transform.World;
		_so.Material = Material.FromShader( "shaders/line.shader" );
		_so.Flags.CastShadows = Shadows && !Additive;
		_so.Attributes.Set( "BaseTexture", Texture );
		_so.Attributes.Set( "BaseTextureSheet", Texture.SequenceData );
		_so.Attributes.Set( "Smoothness", 10 );


		if ( Additive ) _so.Attributes.SetCombo( "D_BLEND", 1 );
		else _so.Attributes.SetCombo( "D_BLEND", 0 );

		_so.Attributes.SetCombo( "D_OPAQUE", 1 );

		_so.Attributes.Set( "g_DepthFeather", DepthFeather );
		_so.Attributes.Set( "g_FogStrength", FogStrength );
		_so.Attributes.Set( "g_ScreenSize", false );

		_so.Flags.IsOpaque = Opaque;
		_so.Flags.IsTranslucent = !Opaque;

		BBox bounds = BBox.FromPositionAndSize( _so.Transform.Position, 10 );

		_so.Init( Graphics.PrimitiveType.LineStripWithAdjacency );

		{
			var list = effect.Particles.AsEnumerable();


			foreach ( var p in list.OrderBy( x => x.Age ) )
			{
				var v = new Vertex();

				bounds = bounds.AddPoint( p.Position );

				var size = p.Size * Scale;

				float sequenceTime = p.SequenceTime.y + p.SequenceTime.z;

				// x is a sequence delta, need to multiply by the sequence length
				if ( p.SequenceTime.x > 0 )
				{
					sequenceTime += p.SequenceTime.x;
				}

				v.TexCoord0 = new Vector4( size.x, size.y, sequenceTime, 0 );
				v.TexCoord1 = p.Color.WithAlphaMultiplied( p.Alpha );

				v.Position = p.Position;

				v.Normal.x = p.Angles.pitch;
				v.Normal.y = p.Angles.yaw;
				v.Normal.z = p.Angles.roll;

				v.Tangent.x = p.Velocity.x;
				v.Tangent.y = p.Velocity.y;
				v.Tangent.z = p.Velocity.z;

				v.Color.r = (byte)(p.Sequence % 255);

				_so.AddVertex( v );
			}

			// expand bounds slightly, based on max particle size?
			bounds.Mins -= Vector3.One * 64;
			bounds.Maxs += Vector3.One * 64;

			_so.Bounds = bounds;
		}
	}
}
