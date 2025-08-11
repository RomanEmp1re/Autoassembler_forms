create FUNCTION dbo.make_diagnosis_xml( -- выпадающий список
	@y int,
	@x int,
	@width int,
	@height int,
	@name varchar(100),
	@prefix varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medDiagnosisList xml;
set @medDiagnosisList = (
	SELECT
		'TmedDiagnosisList' AS [@type],
		@prefix AS [MedDescription],
		@name AS [Name],
		@x AS [Left],
		@y AS [Top],
		@width AS [Width],
		@height AS [Height],
		',' AS [Splitter]
	FOR XML PATH('OBJECT'), TYPE
)
return @medDiagnosisList;
END

