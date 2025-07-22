alter FUNCTION dbo.make_memo_xml( -- текстовое поле
	@y int,
	@x int,
	@width int,
	@height int,
	@text varchar(500),
	@name varchar(100),
	@prefix varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medExMemo xml;
set @medExMemo = (
    SELECT
        'TmedExMemo' AS [@type],
        @prefix AS [MedDescription],
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
		@width AS [Width],
		@height AS [Height],
		(
            SELECT
                'Lines' AS [@type],
                @text AS [Text]
            FOR XML PATH('OBJECT'), TYPE
        )
    FOR XML PATH('OBJECT'), TYPE
)
return @medExMemo;
END
