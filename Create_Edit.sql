create FUNCTION dbo.make_text_edit_xml( -- строка
	@y int,
	@x int,
	@width int,
	@text varchar(500),
	@name varchar(100),
	@prefix varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medExEdit xml;
set @medExEdit = (
    SELECT
        'TmedExEdit' AS [@type],
        @prefix as [MedDescription],
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
		@width AS [Width],
		@text AS [Text]
    FOR XML PATH('OBJECT'), TYPE
)
return @medExEdit;
END;

drop function dbo.make_text_edit_xml