create FUNCTION dbo.make_label_xml( -- создает надпись
	@name varchar(100),
	@y int,
	@x int,
	@caption varchar(500),
	@font_size int
)
RETURNS
XML
AS
BEGIN
declare @medLabel xml;
set @medLabel = (
    SELECT
        'TmedLabel' AS [@type],
        @caption AS [Caption],
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
        -- Font
        (
            SELECT
                'Font' AS [@type],
                '1' AS [Charset],
                '-16777208' AS [Color],
                '-11' AS [Height],
                'Courier New' AS [Name],
				'0' AS [Orientation],
                'fpDefault' AS [Pitch],
                @font_size AS [Size],
				'fqDefault' as [Quality]
            FOR XML PATH('OBJECT'), TYPE
        )
    FOR XML PATH('OBJECT'), TYPE
)
return @medLabel;
END
