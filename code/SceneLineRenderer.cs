public class SceneLineRenderer : SceneDynamicObject
{
	public enum CapStyle
	{
		None = 0,
		Triangle = 1,
		Arrow = 2,
		Rounded = 3
	}

	public CapStyle StartCap
	{
		get => (CapStyle)Attributes.GetInt( "StartCap" );
		set => Attributes.Set( "StartCap", (int)value );
	}
	public CapStyle EndCap
	{
		get => (CapStyle)Attributes.GetInt( "EndCap" );
		set => Attributes.Set( "EndCap", (int)value );
	}

	public bool Wireframe
	{
		get => Attributes.GetComboBool( "D_WIREFRAME" );
		set => Attributes.SetCombo( "D_WIREFRAME", value );
	}

	public int Smoothness
	{
		get => Attributes.GetInt( "Smoothness" );
		set => Attributes.Set( "Smoothness", value );
	}

	public bool Opaque
	{
		set
		{
			Attributes.SetCombo( "D_OPAQUE", value ? 1 : 0 );
			Flags.IsOpaque = value;
			Flags.IsTranslucent = !value;
		}
	}

	public SceneLineRenderer( SceneWorld sceneWorld ) : base( sceneWorld )
	{
		Material = Material.FromShader( "shaders/line.shader" );
		Attributes.Set( "BaseTexture", Texture.White );
		Init( Graphics.PrimitiveType.LineStripWithAdjacency );
	}

	int _points = 0;
	BBox _bounds;
	Vertex _v;

	public void StartLine()
	{
		Init( Graphics.PrimitiveType.LineStripWithAdjacency );
		_points = 0;
		_bounds = BBox.FromPositionAndSize( Transform.Position, 10 );
	}

	public void AddLinePoint( in Vector3 pos, Color color, float width )
	{
		_v.TexCoord0 = new Vector4( width, 0, 0, 0 );
		_v.TexCoord1 = color;
		_v.Position = pos;

		AddVertex( _v );

		// if it's the start, add twice
		if ( _points == 0 )
			AddVertex( _v );

		_bounds = _bounds.AddPoint( pos );
		_points++;
	}

	public void EndLine()
	{
		// add again for the end point
		if ( _points > 0 )
			AddVertex( _v );

		Bounds = _bounds;
	}


}
