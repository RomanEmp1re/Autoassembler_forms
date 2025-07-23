declare
	@default_width int = 900;

declare -- ��������� ��������������, ������ � �������� ������������ ����������
	@elements table(id int,
		structure varchar(20),
		[type] varchar(20), 
		prefix varchar(100), 
		[row] int,
		[col] int,
		cnt_str int, 
		width int, 
		[default] varchar(4000), 
		items varchar(4000),
		is_last_in_row bit
);

-- ���������� ������� � ��������
insert into @elements
select
	id,
	case structure
		when '���������' then 'header'
		when '�������' then 'postfix'
	end as structure,
	case [type]
		when '��' then 'Memo'
		when '��' then 'ComboBox'
		when '������' then 'Edit'
		when '�������' then 'Label'
		else '����������� �������'
	end as type,
	prefix,
	row,
	row_number() over (partition by row order by id) - 1 as col,
	case [type]
		when '��' then case
			when cnt_str > 0 then cnt_str
			else 1
		end
		else 0
	end as cnt_str,
	case
		when type = '��' then @default_width
		when type =  'Label' then len(prefix) * 8 -- ������������ ������ �������, ����� ����� �������� ���������
		else width
	end as width,
	isnull([default], '') as [default],
	case [type]
		when '��' then case
			when items is not null then items
			else '��'+char(10)+'���'
		end
		else null
	end as items,
	case -- ������� ����, ��� ������� �������� ��������� � ������
		when structure = '������' then null
		when 
			lead([row]) over (order by id) <> [row] -- ��������� ������ ����� ������ �����
			or lead(structure) over (order by id) = '������' -- ��� ��������� ������� - ������
			or lead(id) over (order by id) is null -- ��� ��� ������ ��������� ������� �� ���� ���������
		then 1
		else 0
	end as is_last_in_row
from TestData$
where id > 0
	and (row > 0 or structure = '���������')

select * from @elements

declare 
	@epmzname varchar(200) = '��� ����� ���', -- �������� ����� (� ���� ���� ������������ ������ 100, ���� �������� ����� 100 �������� - ��� ���������, � ����� - 200)
	@type varchar(20) = '', -- ��� ��������
    @prefix varchar(100) = '', -- ��� meddescription � �������� ����� ����������
	@G int = -1, -- ������� ������
	@row int = 0, -- ������� ������ � ���������
	@column int = 0, -- ������� ������� � ���������
	@height int = 0, -- ������ ��������
	@width int = 0, -- ������ ��������
	@postfix varchar(50) = '', -- �������� - ��� �������, ������� ����� ��������� ����� ��������
	@default nvarchar(4000) = '', -- ��������� �������� ��������
	@labelcount int = 0,
	@items nvarchar(4000) = '', -- ������ ��������� ����������� ������
	@structure varchar(10),
	@fontstyle varchar(30),
	@fontsize int,
	@is_last_in_row bit = 0;

	declare @ex_groupname varchar(100)= '', -- ��� ������� ������
	@y int = 5, -- ������� ���������� �� y (�������� top � ��������)
	@x int = 5, -- ������� ���������� �� x (�������� left � ��������)
	@startx int = 5, -- ������ �����
	@dy int = 5, -- ����������� �������� ����� ���������� � �����, ����� �������� �� �������
	@dy_group int = 10, -- ����������� �������� ��� ��������, ����� �������� �� �������
	@parentgroup int = -1,
	@group_col int = 0,
	@dx int = 5, -- ����������� �������� ����� ���������� �� ������
	@C int = 0, -- ������� �������
	@exR int = -1, -- ������� ������
	@R int = 0, -- ������� ������
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
		'Courier New' AS [form/@Font.Name],
		(-- ��� �� ��������� ����� �� ������� ������� - �������� �����
			SELECT dbo.make_label_xml('FormTitle', @y, @x, @epmzname, 14, 'fsBold')
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
	[row],
	col,
	cnt_str,
	width,
	[default],
	items,
	is_last_in_row
from @elements
where type in ('��', '��', '������', '������')
open Cur;
    fetch next from Cur
		into 
			@structure,
			@type,
			@prefix,
			@R,
			@C,
			@cnt_str
			@width,
			@default,
			@items,
			@is_last_in_row
    while @@FETCH_STATUS = 0
	begin
		-- ���������� �����
		if @structure = 'group' -- ���� ������� - ��������� ������
		begin -- ���������� ��������� ������, ���������� column � row, x � y
			set @G = @G+ 1;
			set @elementName = dbo.make_group_name(@G, @parent_group, @group_col);
			set @fontstyle = 'fsBold';
		end;
		if @structure = 'postfix'
		begin
			set @fontstyle = '';
			set @elementName = dbo.make_element_name(@G, @R, @C, 1, 0);
		end
		-- ��� ���������� �������� ��������
		if @structure is null
		begin	
			set @fontstyle = '';
			set @elementName = dbo.make_element_name(@G, @R, @C, 0, 0);
		end

		-- ��������� �������

		if @type = 'Label'
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					@elementName,
					@y,
					@x,
					@prefix,
					12,
					''
				)
			);	
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + 8*len(@prefix) + dx;
		end;

		if @type = '��' -- ���� ��������� ����, �� ��������� ������� � ���� � ������ ��������� ����
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + cast(@labelcount as varchar(3)),
					@y,
					@x,
					@prefix,
					12,
					''
				)
			);	
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @labelcount = @labelcount + 1;
			set @y = @y + 18 + @dy; -- 18 - �������� ��� 12 ������
			set @FormElement = (
				select dbo.make_memo_xml( -- ���� ��������� ����
					@y, 
					@x, 
					900, 
					@cnt_str * 18 + 8, -- ��������� ���������� ������ �� ���� ���-�� ����� ��� ������ courier new
					isnull(@default, ''), 
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @y = @y + @height + @dy;
		end;


		begin
			if @cur_row = @ex_row -- ��������� ������ �������, ��������� �� �� �� ������� ������ ��� ���
			begin -- ���� ��, ��������� �� X
				set @cur_col = @cur_col + 1
				set @ex_col = @cur_col;
				set @x = @x + @dx;
			end;
			else -- ���� ���, �� ���������� ���� �� Y
			begin
				set @ex_row = @cur_row;
				set @cur_col = 0;
				set @x = @startx;
				set @y = @y + @dy;
			end;
		end;
		-- ��������� ��� �������� (����� ���� ����� �������� ������� ����������)
		set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 0, 0)
		-- ��������� ����
		if @type = '��' -- ���� ��������� ����, �� ��������� ������� � ���� � ������ ��������� ����
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + cast(@labelcount as varchar(3)),
					@y,
					@x,
					@prefix,
					12,
					''
				)
			);	
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @labelcount = @labelcount + 1;
			set @y = @y + 18 + @dy; -- 18 - �������� ��� 12 ������
			set @FormElement = (
				select dbo.make_memo_xml( -- ���� ��������� ����
					@y, 
					@x, 
					900, 
					@height, 
					isnull(@default, ''), 
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @y = @y + @height + @dy;
		end;
		-- ������� ����� �������
		if @type in ('������', '��', '����')
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + cast(@labelcount as varchar(3)),
					@y,
					@x, 
					@prefix, 
					12,
					''
				)
			);
			set @x = @x + len(@prefix) * 12;
			set @labelcount = @labelcount + 1;
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
		end;
		-- ������
		if @type = '������'
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
			set @x = @x + @width;
			set @labelcount = @labelcount + 1
			if @is_last_in_row = 1 
			begin
				set @y = @y + 26; -- ��������� ��� ����� � �� �� 12 ������
			end;
		end;
		-- ���������� ������
		if @type = '��'
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
			set @x = @x + @width;
			if @is_last_in_row = 1 
			begin
				set @y = @y + 26; -- ��������� ��� ����� � �� �� 12 ������
			end;
		end;
		-- ��������
		if @type in ('��', '������') and @postfix <> ''
		begin
			set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 1, 0)
			set @x = @x + len(@postfix) * 12;
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					@elementName, 
					@y, 
					@x, 
					@prefix, 
					12,
					''
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + len(@postfix) * 12;
		end;
		
		fetch next from Cur 
		into 
			@structure,
			@type,
			@prefix,
			@R,
			@C
			@cnt_str,
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
@EpmzCode = '2',
@EpmzName = '��� ����� ���',
@EpmzGroupId = 1,
@FormName = '��� ����� ���',
@FormContent = @FormContent,
@HtmlTemplate = '',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';
*/
-- ��� ������ CourierNew 10 ����� ������ label �� 1 ������ - 8

--delete from CUSTOM_MED_FORMS where name = '��� ����� ���'
--delete from epmz_types where name = '��� ����� ���'