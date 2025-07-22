create FUNCTION dbo.make_combobox_xml( -- выпадающий список
	@y int,
	@x int,
	@width int,
	@text varchar(500),
	@name varchar(100),
	@items varchar(1000),
	@prefix varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medExComboBox xml;
set @medExComboBox = (
    SELECT
        'TmedExComboBox' AS [@type],
        @prefix AS [MedDescription],
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
		@width AS [Width],
		(
            SELECT
                'Properties' AS [@type],
				(
					SELECT
						'Items' AS [@type],
						replace(@items, '|', char(10)) AS [Text]
					FOR XML PATH('OBJECT'), TYPE
				)
            FOR XML PATH('OBJECT'), TYPE
        ),
		@text as [text]
    FOR XML PATH('OBJECT'), TYPE
)
return @medExComboBox;
END
