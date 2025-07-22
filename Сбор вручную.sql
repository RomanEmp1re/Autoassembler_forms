CREATE FUNCTION dbo.make_label_xml( -- создает надпись
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
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
        @caption AS [Caption],
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


CREATE FUNCTION dbo.make_text_edit_xml( -- строка
	@y int,
	@x int,
	@width int,
	@text varchar(500),
	@name varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medExEdit xml;
set @medExEdit = (
    SELECT
        'TmedExEdit' AS [@type],
        @name AS [Name],
        @x AS [Left],
        @y AS [Top],
		@width AS [Width],
		@text AS [Text]
    FOR XML PATH('OBJECT'), TYPE
)
return @medExEdit;
END;

CREATE FUNCTION dbo.make_memo_xml( -- текстовое поле
	@y int,
	@x int,
	@width int,
	@height int,
	@text varchar(500),
	@name varchar(100)
)
RETURNS
XML
AS
BEGIN
declare @medExMemo xml;
set @medExMemo = (
    SELECT
        'TmedExMemo' AS [@type],
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

CREATE FUNCTION dbo.make_combobox_xml( -- выпадающий список
	@y int,
	@x int,
	@width int,
	@text varchar(500),
	@name varchar(100),
	@items varchar(1000)
)
RETURNS
XML
AS
BEGIN
declare @medExComboBox xml;
set @medExComboBox = (
    SELECT
        'TmedExComboBox' AS [@type],
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

-- DROP function dbo.make_label_xml
-- DROP function dbo.make_text_edit_xml
-- DROP function dbo.make_memo_xml
-- DROP function dbo.make_combobox_xml


declare @F xml = (SELECT
		'designform_frm' AS [form/@Name],
		'Ёкранна€ форма' AS [form/@Caption],
		'1049' AS [form/@Width],
		'891' AS [form/@Height],
		'-16777201' AS [form/@Color],
		'-16777208' AS [form/@Font.Color],
		'12' AS [form/@Font.Size],
		'Courier New' AS [form/@Font.Name],

		(
			-- ¬ложенный OBJECT (из предыдущего запроса)
			SELECT dbo.make_label_xml('label1', 100, 100, '„евапчичи', 16)
			for xml path(''), type
		) AS [form],
		'' as [GroupsForPF],
		'<table>  </table>' AS [HtmlTemplate/@Content],
		'0' AS [HtmlTemplate/@StdTemplate]
	FOR XML PATH(''), ROOT('FormConstructor')
);

declare @new_F xml = (select dbo.make_text_edit_xml(140, 100, 400, 'default', 'JALOBY'));

set @F.modify('insert sql:variable("@new_F")
	as last into (/FormConstructor/form)[1]'
);

set @new_F = (select dbo.make_memo_xml(180, 100, 400, 101, 'Ўимпанзини бананини', 'coolguy'));

set @F.modify('insert sql:variable("@new_F")
	as last into (/FormConstructor/form)[1]'
);

set @new_F = (select dbo.make_combobox_xml(180, 100, 400, 'Ўимпанзини бананини', 'italian_animals', 'Bombardiro Crocodilo|Shimpanzini Bananini|Tralalelo Tralala'));

set @F.modify('insert sql:variable("@new_F")
	as last into (/FormConstructor/form)[1]'
);

select @F



EXECUTE sp_iu_custom_med_form_and_epmz_type
@EpmzTypeId = 0,
@EpmzCode = '6',
@EpmzName = 'это пранк бро',
@EpmzGroupId = 1, -- диагностика
@FormName = 'это пранк бро',
@FormContent = @F,
@HtmlTemplate = '<table>  </table>',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';



delete from custom_med_forms where name = 'это пранк бро'

delete from epmz_types where name = 'это пранк бро';

SELECT * FROM custom_med_forms where name like '%пранк%'

insert into EGISZ_FORMS_DOCTYPES values (0, 0, 12021)