--if object_id('tempdb..#tmp_1') is not null
--   drop table [tempdb].[tmp_1];

-- ��� ����������� �������, � ������� ���������� ������������� excel
/*create table [tempdb].[tmp_1] (
   type varchar(20),
   prefix varchar(100),
   groupname varchar(100),
   [row] int,
   [column] int,
   height int,
   width int,
   postfix varchar(50),
   [default] varchar(1000)
)*/
-- ����� �� ��������� ������� ������� ������


-- select * from TestData



declare @epmzname varchar(200) = '��� ����� ���', -- �������� ����� (� ���� ���� ������������ ������ 100, ���� �������� ����� 100 �������� - ��� ���������, � ����� - 200)
	@type varchar(20) = '', -- ��� ��������
    @prefix varchar(100) = '', -- ��� meddescription � �������� ����� ����������
	@group int = -1, -- ������� ������
	@row int = 0, -- ������� ������ � ���������
	@column int = 0, -- ������� ������� � ���������
	@height int = 0, -- ������ ��������
	@width int = 0, -- ������ ��������
	@postfix varchar(50) = '', -- �������� - ��� �������, ������� ����� ��������� ����� ��������
	@default varchar(1000) = '', -- ��������� �������� ��������
	@items varchar(2000) = ''; -- ������ ��������� ����������� ������

	declare @ex_groupname varchar(100)= '', -- ��� ������� ������
	@y int = 5, -- ������� ���������� �� y (�������� top � ��������)
	@x int = 5, -- ������� ���������� �� x (�������� left � ��������)
	@dy int = 5, -- ����������� �������� ����� ���������� � �����, ����� �������� �� �������
	@dy_group int = 30, -- ����������� �������� ����� ��������, ����� �������� �� �������
	@parentgroup int = -1,
	@group_col int = 0,
	@dx int = 5, -- ����������� �������� ����� ���������� �� ������
	@cur_col int = 0, -- ������� �������
	@ex_col int = 0, -- ������� �������
	@ex_row int = 0, -- ������� ������
	@cur_row int = 0, -- ������� ������
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
			SELECT dbo.make_label_xml('FormTitle', @y, @x, @epmzname, 14)
			for xml path(''), type
		) AS [form],
		'' as [GroupsForPF],
		'<table>  </table>' AS [HtmlTemplate/@Content],
		'0' AS [HtmlTemplate/@StdTemplate]
	FOR XML PATH(''), ROOT('FormConstructor')
);
-- ���������� �� ���������
declare Cur cursor local static forward_only
FOR SELECT [type], 
    prefix,
	[row],
	[column],
	height,
	width,
	postfix,
	[default] 
from TestData
open Cur;
    fetch next from Cur
		into @type,
			@prefix,
			@row,
			@column,
			@height,
			@width,
			@postfix,
			@default;
    while @@FETCH_STATUS = 0
	begin
		if @type = 'group' -- ���� ������� - ��������� ������
		begin -- ���������� ��������� ������, ���������� column � row
			set @cur_col = 0;
			set @cur_row = 0;
			set @ex_row = 0;
			set @ex_col = 0;
			set @group = @group + 1;
			set @x = 0;
			set @y = @y + @dy_group;
		-- ��������� ��������� ������
			set @FormElement = (
				select dbo.make_label_xml(
					dbo.make_group_name(@group, @parentgroup, @group_col), 
					@y, 
					@x, 
					@prefix, 
					14
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @y = @y + 20 + @dy_group; -- 20 - ��������� ��� ������ courier new 14 �����
		end;
		else -- ���� ������ ��� �������
		begin
			if @cur_row = @ex_row -- ��������� ������ �������, ��������� �� �� �� ������� ������ ��� ���
			begin -- ���� ��, ��������� �� X
				set @ex_col = @cur_col;
				set @cur_col = @cur_col + 1;
				set @x = @x + @dx;
			end;
			else -- ���� ���, �� ���������� ���� �� Y
			begin
				set @ex_row = @cur_row;
				set @cur_row = @cur_row + 1;
				set @x = 5;
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
					'Label' + @elementName,
					@y,
					@x,
					@prefix,
					12
				)
			);	
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @y = @y + 22 + @dy;
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
					'Label' + @elementName,
					@y,
					@x, 
					@prefix, 
					12
				)
			);
			set @x = @x + len(@prefix) * 12;
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
		end;
		-- ��������
		if @type in ('��', '������') and @postfix <> ''
		begin
			set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 1, 0)
			set @x = @x + len(@postfix) * 12;
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					'Label' + @elementName, 
					@y, 
					@x, 
					@prefix, 
					12
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @x = @x + len(@postfix) * 12;
		end;
		fetch next from Cur 
		into @type,
			@prefix,
			@groupname,
			@row,
			@column,
			@height,
			@width,
			@postfix,
			@default;
	end                                
close Cur;                                            
deallocate Cur;

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