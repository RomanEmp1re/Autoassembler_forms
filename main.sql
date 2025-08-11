
declare
	@default_width int = 900, -- ���������� ������ ���������. ������ ���� ������ �������� �� �����������
	@default_font varchar(20) = 'Segoe UI', -- ��������� ����� ��� �����. ����������� ��� ���� �����
	@header_style varchar(50) = 'fsBold', -- ����� ��� ����������
	@epmzname varchar(200) = '��� ����� ���', -- �������� ���������� ���� � ������� � ���������
	@startx int = 5; -- ��������� ������� �����

declare -- ��������� ��������������, ������ � �������� ������������ ����������
	@elements table(
		id int,
		structure varchar(20),
		[type] varchar(20), 
		prefix varchar(100),
		groupid int,
		[row] int,
		[col] int,
		[depth] int,
		element_name varchar(50),
		height int, 
		width int, 
		[default] varchar(4000), 
		items varchar(4000),
		is_last_in_row bit
);

-- ���������� ������� � ��������
with prepare as (
	select
		id,
		isnull(
			(
				select top 1 tt.id
				from TestData$ as tt
				where tt.structure = 'header'
					and tt.id <= t.id
				order by tt.id desc
			), 
		0) as groupid,
		structure,
		[type],
		prefix,
		[row],
		case [type]
			when 'memo' then cnt_str * 18 + 8
			when 'diagnosis' then cnt_str * 18 + 8
			else 26
		end as height,
		case
			when type = 'memo' then @default_width
			when type =  'label' then len(prefix) * 8 -- ������������ ������ �������, ����� ����� �������� ���������
			else width
		end as width,
		isnull([default], '') as [default],
		case [type]
			when 'combo' then case
				when items is not null then items
				else '��'+char(10)+'���'
			end
			else null
		end as items,
		case -- ������� ����, ��� ������� �������� ��������� � ������
			when 
				lead([row]) over (order by id) <> [row] -- ��������� ������ ����� ������ �����
				or lead(structure) over (order by id) = 'header' -- ��� ��������� ������� - ���������
				or lead(id) over (order by id) is null -- ��� ��� ������ ��������� ������� �� ���� ���������
				or structure = 'header'
			then 1
			else 0
		end as is_last_in_row
	from TestData$ as t
	where id > 0
		and (row >= 0 or structure = 'header')
),
prepare_2 as (
	select
		id,
		dense_rank() over (order by groupid) - 2 as groupid,
		structure,
		[type],
		prefix,
		[row],
		row_number() over (partition by groupid, [row] order by id) - 1 as col,
		case structure
			when 'postfix' then 1
			else null
		end as depth,
		height,
		width,
		[default],
		items,
		is_last_in_row
	from prepare
),
prepare_3 as (
	select 
		id,
		structure,
		[type],
		prefix,
		groupid,
		[row],
		case structure
			when 'postfix' then lag(col) over (order by id)
			else col
		end as col,
		depth,
		height,
		width,
		[default],
		items,
		is_last_in_row
	from prepare_2
)
insert into @elements
select
	id,
	structure,
	[type],
	prefix,
	groupid,
	[row],
	[col],
	[depth],
	case structure
		when 'header' then dbo.make_group_name(groupid, -1, 0)
		else dbo.make_element_name(groupid, [row], [col], depth, -1)
	end as element_name,
	height,
	width,
	[default],
	items,
	is_last_in_row
from prepare_3
order by groupid, id

select * from @elements

declare 
	@type varchar(20) = '', -- ��� ��������
    @prefix varchar(100) = '', -- ��� meddescription � �������� ����� ����������
	@column int, -- ������� ������� � ���������
	@height int = 0, -- ������ ��������
	@width int = 0, -- ������ ��������
	@default nvarchar(4000) = '', -- ��������� �������� ��������
	@labelcount int = 0, -- ������� �������� ��� ���������, ������� �� ���������� �����������
	@items nvarchar(4000) = '', -- ������ ��������� ����������� ������
	@structure varchar(10),
	@fontstyle varchar(30),
	@is_last_in_row bit = 0;

	declare @ex_groupname varchar(100)= '', -- ��� ������� ������
	@y int = 5, -- ������� ���������� �� y (�������� top � ��������)
	@x int = 5, -- ������� ���������� �� x (�������� left � ��������)
	@dy int = 5, -- ����������� �������� ����� ���������� � �����
	@dy_group int = 10, -- ����������� �������� ��� ��������
	@parentgroup int = -1,
	@group_col int = 0,
	@dx int = 5, -- ����������� �������� ����� ���������� �� ������
	@G int = 0, -- ������� ������
	@C int = 0, -- ������� �������
	@R int = 0, -- ������� ������
	@D int = 0,
	@cnt_str int = 0, -- ���-�� ����� � 
	@FormContent xml, -- xml, ������� ����� �� ������
	@FormElement xml, -- ����� xml, ������� ����� ����������� � @FormContent
	@elementName varchar(50); -- ��� ��������

set @FormContent = (
	SELECT -- �������������� �����, ����� �� ������� ����� ������ ����������� ����� ��� ���������, ������������� courier new 12 �������, ��������� �� monotype � ����� ��������� ���������
		'designform_frm' AS [form/@Name],
		'�������� �����' AS [form/@Caption],
		'1049' AS [form/@Width],
		'891' AS [form/@Height],
		'-16777201' AS [form/@Color],
		'-16777208' AS [form/@Font.Color],
		'12' AS [form/@Font.Size],
		@default_font AS [form/@Font.Name],
		(-- ��� �� ��������� ����� �� ������� ������� - �������� �����
			SELECT dbo.make_label_xml('FormTitle', @y, @x, @epmzname, 14, 'fsBold', @default_font)
			for xml path(''), type
		) AS [form],
		'' as [GroupsForPF],
		'<table>  </table>' AS [HtmlTemplate/@Content],
		'0' AS [HtmlTemplate/@StdTemplate]
	FOR XML PATH(''), ROOT('FormConstructor')
);
set @y = @y + 22; -- 22 - ��������� ��� 14 ������
-- ���������� �� ���������
declare Cur cursor local static forward_only
FOR 
SELECT 
	structure,
	[type], 
    nullif(prefix, ''),
	groupid,
	[row],
	col,
	depth,
	element_name,
	height,
	width,
	[default],
	items,
	is_last_in_row
from @elements
where type in ('Combo', 'Memo', 'Edit', 'Label', 'Diagnosis')
order by groupid, id
open Cur;
    fetch next from Cur
		into 
			@structure,
			@type,
			@prefix,
			@G,
			@R,
			@C,
			@D,
			@elementName,
			@height,
			@width,
			@default,
			@items,
			@is_last_in_row
    while @@FETCH_STATUS = 0
	begin -- ���������� �����
		if @structure = 'header' -- ���� ������� - ��������� ������
			set @fontstyle = @header_style;
		else
			set @fontstyle = '';

		-- ��������� �������

		if @type = 'Label'
		begin
			set @height = 26;
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					@elementName,
					@y,
					@x,
					@prefix,
					12,
					@fontstyle,
					@default_font
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + 8*len(@prefix) + @dx;
		end;

		if @type in ('Memo', 'Diagnosis') -- ���� ��������� ���� ��� �������, �� ��������� ������� � ���� � ������ ��������� ����
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + cast(@labelcount as varchar(3)),
					@y,
					@x,
					@prefix,
					12,
					@fontstyle,
					@default_font
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @labelcount = @labelcount + 1;
			set @y = @y + 18 + @dy; -- 18 - �������� ��� 12 ������
		end;

		if @type = 'memo'
		begin
			set @FormElement = (
				select dbo.make_memo_xml( -- ���� ��������� ����
					@y, 
					@x, 
					@width, 
					@height, 
					isnull(@default, ''), 
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
		end;

		if @type = 'diagnosis'
		begin
			set @FormElement = (
				select dbo.make_diagnosis_xml( -- ��� ������ ���������
					@y, 
					@x, 
					@width, 
					@height,
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
		end;

		if @type in ('Edit', 'Combo', 'CheckCombo', 'Date') and @prefix <> ''
		begin
			if (@x + @dx + len(@prefix) * 10 > @default_width) or (@x + @dx + len(@prefix) * 10 + @width > @default_width)
			begin
				set @x = @startx;
				set @y = @y + @dy + @height;
			end;
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + cast(@labelcount as varchar(3)),
					@y,
					@x,
					@prefix,
					12,
					@fontstyle,
					@default_font
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + @dx + len(@prefix) * 10;
			set @labelcount = @labelcount + 1;
			if @x + @dx + @width > @default_width
			begin
				set @x = @startx;
				set @y = @y + @dy + @height;
			end;
		end;

		if @type = 'Edit'
		begin
			set @FormElement = (
				select dbo.make_text_edit_xml( -- ���� ��������� ����
					@y,
					@x,
					@width,
					isnull(@default, ''),
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + @width + @dx;
		end;

		if @type = 'Combo'
		begin
			set @FormElement = (
				select dbo.make_combobox_xml( -- ���� ��������� ����
					@y, 
					@x, 
					@width, 
					isnull(@default, ''), 
					@elementName,
					@items,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + @width + @dx;
		end;

		if @is_last_in_row = 1
		begin
			set @x = @startx;
			set @y = @y + @height + @dy;
		end;
		
		fetch next from Cur 
		into 
			@structure,
			@type,
			@prefix,
			@G,
			@R,
			@C,
			@D,
			@elementName,
			@height,
			@width,
			@default,
			@items,
			@is_last_in_row
	end                                
close Cur;                                            
deallocate Cur;

select @FormContent

/*
EXECUTE sp_iu_custom_med_form_and_epmz_type
@EpmzTypeId = 0,
@EpmzCode = '63',
@EpmzName = '��� ������� ����� ��� 3',
@EpmzGroupId = 1,
@FormName = '��� ������� ����� ��� 3',
@FormContent = @FormContent,
@HtmlTemplate = '',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';*/

-- ��� ������ CourierNew 10 ����� ������ label �� 1 ������ - 8

--delete from CUSTOM_MED_FORMS where name = '��� ����� ���'
--delete from epmz_types where name = '��� ����� ���'