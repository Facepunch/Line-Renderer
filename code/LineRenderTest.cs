using Sandbox.Utility;

public sealed class LineRenderTest : Component, Component.ExecuteInEditor
{
	SceneLineRenderer _so;

	[Property] public bool Jubble { get; set; }

	[Property] public int Octaves { get; set; } = 2;
	[Property] public float Noising { get; set; } = 2;
	[Property] public float Speed { get; set; } = 1;

	[Property] public List<Vector3> Points { get; set; }


	[Property] public SceneLineRenderer.CapStyle StartCap { get; set; }
	[Property] public SceneLineRenderer.CapStyle EndCap { get; set; }
	[Property] public bool Wireframe { get; set; }
	[Property] public bool Opaque { get; set; }
	[Property] public Gradient Color { get; set; } = global::Color.Cyan;
	[Property] public Curve Width { get; set; } = 5;
	[Property, Range( 0, 64 )] public int Smoothness { get; set; } = 0;

	protected override void DrawGizmos()
	{
		if ( Points is null )
			return;

		if ( !Gizmo.IsSelected )
			return;

		for ( int i = 0; i < Points.Count; i++ )
		{
			using var scope = Gizmo.Scope( $"Point {i}", new Transform( Points[i] ) );

			if ( Gizmo.Control.Position( "Point " + i, Points[i], out var newPoint ) )
			{
				Points[i] = newPoint;
			}
		}
	}

	protected override void OnEnabled()
	{
		_so = new SceneLineRenderer( Scene.SceneWorld );
		_so.Transform = Transform.World;
	}
	protected override void OnDisabled()
	{
		_so?.Delete();
		_so = null;
	}

	protected override void OnUpdate()
	{
		if ( _so is null ) return;

		_so.StartCap = StartCap;
		_so.EndCap = EndCap;
		_so.Wireframe = Wireframe;
		_so.Opaque = Opaque;
		_so.Smoothness = Smoothness;

		_so.RenderingEnabled = true;
		_so.Transform = Transform.World;
		_so.Material = Material.FromShader( "shaders/line.shader" );
		_so.Flags.CastShadows = true;
		_so.Attributes.Set( "BaseTexture", Texture.White );
		_so.Attributes.SetCombo( "D_BLEND", 0 );

		if ( Jubble )
		{
			AddJubble();
			return;
		}

		_so.StartLine();

		int i = 0;
		foreach ( var p in Points )
		{
			float delta = (float)i / (float)Points.Count;

			_so.AddLinePoint( Transform.World.PointToWorld( p ), Color.Evaluate( delta ), Width.Evaluate( delta ) );

			i++;
		}

		_so.EndLine();
	}

	void AddJubble()
	{
		_so.StartLine();

		float points = 200;

		for ( float f = 0; f < points; f++ )
		{
			var pos = Noise.FbmVector( Octaves, RealTime.Now * 0.1f, RealTime.Now * -20.5f * Speed + f * Noising ) * 200.0f;

			_so.AddLinePoint( Transform.World.PointToWorld( pos ), Color.Evaluate( f / points ), Width.Evaluate( f / points ) );

		}

		_so.EndLine();

	}


}
