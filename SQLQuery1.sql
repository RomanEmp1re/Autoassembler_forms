if object_id('tempdb..#tmp_1') is not null
   drop table [tempdb].[tmp_1];

create table [tempdb].[tmp_1] (
   type varchar(20),
   meddescription varchar(100),
   groupname varchar(100),
   groupalias varchar(50),
   [row] int,
   [column] int,
   height int,
   width int,
   postfix varchar(50),
   [default] varchar(1000)
)
-- ����� �� ��������� ������� ������� ������


declare @epmzname varchar(200), -- �������� ����� (� ���� ���� ������������ ������ 100, ���� �������� ����� 100 �������� - ��� ���������, � ����� - 200)
	@type varchar(20) = '', -- ��� ��������
    @prefix varchar(100) = '', -- ��� meddescription � �������� ����� ����������
	@groupname varchar(100) = '', -- �������� �������� ������
	@groupalias varchar(50) = '', -- ��������� ������ ��� ������������ ���������
	@row int = 0, -- ������� ������ � ���������
	@column int = 0, -- ������� ������� � ���������
	@height int = 0, -- ������ ��������
	@width int = 0, -- ������ ��������
	@postfix varchar(50) = '', -- �������� - ��� �������, ������� ����� ��������� ����� ��������
	@default varchar(1000) = '', -- ��������� �������� ��������
	@items varchar(2000) = '';

	@ex_groupalias varchar(50)= '', -- ��������� ������� ������
	@y int = 5, -- ������� ���������� �� y (�������� top � ��������)
	@x int = 5, -- ������� ���������� �� x (�������� left � ��������)
	@interval int = 5, -- ����������� �������� ����� ���������� � �����, ����� �������� �� �������
	@group_interval int = 10, -- ����������� �������� ����� ��������, ����� �������� �� �������
	@cur_column int = 0, -- ������� �������
	@ex_column int = 0,
	@ex_row int = 0,
	@cur_row int = 0, -- ������� ������
	@FormContent xml, -- xml, ������� ����� �� ������
	@FormElement xml, -- ����� xml, ������� ����� ����������� � @FormContent
	@elementName varchar(50); -- ��� ��������

declare @FormContent xml = (SELECT -- �������������� �����, ����� �� ������� ����� ������ ����������� ����� ��� ���������, ������������� courier new 12 �������, ��������� �� monotype � ����� ��������� ���������
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

declare Cur cursor local static forward_only
FOR SELECT [type], 
    meddescription,
	groupname,
	groupalias,
	[row],
	[column],
	height,
	width,
	postfix,
	[default] 
from [tempdb].[tmp_1]
open Cur;
    fetch next from Cur
		into @type,
			@prefix,
			@groupname,
			@groupalias,
			@row,
			@column,
			@height,
			@width,
			@postfix,
			@default;
    while @@FETCH_STATUS = 0
	begin
		if @groupalias <> @ex_groupalias -- ���� ������ �����
		begin -- ���������� ��������� ������, ���������� column � row
			set @cur_column = 0;
			set @cur_row = 0;
			set @ex_row = 0;
			set @ex_column = 0;
			set @x = 0;
			set @y = @y + @group_interval;
		-- ��������� ��������� ������
			set @FormElement = (
				select dbo.make_label_xml(
					@groupalias + 'Title' + @num, 
					@y, 
					@x, 
					@groupname, 
					12,
					1
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @ex_groupalias = @groupalias; -- ��������� ������� ������ ��� ��������� ��������
			set @y = @y + 18 + @interval; -- 18 - ��������� ��� ������ courier new
		end;
		else -- ���� ������ ��� �������
		begin
			if @cur_row = @ex_row -- ��������� ������ �������, ��������� �� �� �� ������� ������ ��� ���
			begin -- ���� ��, ��������� �� X
				set @ex_column = @cur_column;
				set @cur_column = @cur_column + 1;
				set @x = @x + @interval;
			end;
			else -- ���� ���, �� ���������� ���� �� Y
				set @ex_row = @cur_row;
				set @cur_row = @cur_row + 1;
				set @x = 5;
				set @y = @y + @interval;
			end;
		end;
		-- ��������� ����
		if @type = '��' -- ���� ��������� ����, �� ��������� ������� � ���� � ������ ��������� ����
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					@groupalias + 'Title' + cast(@cur_row as varchar(2)) + cast(@cur_row as varchar(2)),
					@y,
					@x,
					@prefix,
					12,
					1
				)
			);	
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
			set @elementName = dbo.make_element_name(@groupalias, 0, @cur_column, @cur_row);
			set @y = @y + @height + @interval;
			set @FormElement = (
				select dbo.make_memo_xml( -- ���� ��������� ����
					@y, 
					@x, 
					900, 
					@height, 
					@default, 
					@elementName,
					@prefix
				)
			);
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
		end;
		-- ������� ����� �������
		if @type in ('������', '��')
		begin
			set @ElementName = dbo.make_element_name(@groupalias + 'Title', 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_label_xml( -- ������� ����� ��������� �����
					@elementName,
					@y,
					@x, 
					@prefix, 
					12,
					1
				)
			);
			set @x = @x + len(@prefix) * 8;
			set @FormContent.modify('insert sql:variable("@FormElement")
				as last into (/FormConstructor/form)[1]'
			);
		end;
		-- ������
		if @type = '������'
		begin
			set @elementName = dbo.make_element_name(@groupalias, 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_text_edit_xml( -- ���� ��������� ����
					@y, 
					@x, 
					@width, 
					26, 
					@default, 
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
			set @elementName = dbo.make_element_name(@groupalias, 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_combobox_xml( -- ���� ��������� ����
					@y, 
					@x, 
					@width, 
					@height,
					@default, 
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
		if @type in ('��', '������')
		begin
			if @postfix <> '' -- ��������� �������� ����� ������
			begin
				set @x = @x + len(@postfix) * 8;
				set @elementName = dbo.make_element_name(@groupalias, 1, @cur_column, @cur_row);
				set @FormElement = (
					select dbo.make_label_xml( -- ������� ����� ��������� �����
						@groupalias + 'Title' + cast(@cur_row as varchar(2)) + cast(@cur_row as varchar(2)), 
						@y, 
						@x, 
						@prefix, 
						12,
						1
					)
				);
				@x = @x + len(@postfix) * 8;
			end;
		end
		fetch next from Cur 
		into @type,
			@prefix,
			@groupname,
			@groupalias,
			@row,
			@column,
			@height,
			@width,
			@postfix,
			@default;
	end;                                      
close Cur;                                            
deallocate Cur;


EXECUTE sp_iu_custom_med_form_and_epmz_type
@EpmzTypeId = 0,
@EpmzCode = '2',
@EpmzName = '��� ����� ���',
@EpmzGroupId = 1,
@FormName = '��� ����� ���',
@FormContent = @F,
@HtmlTemplate = '',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';

-- ��� ������ CourierNew 10 ����� ������ label �� 1 ������ - 8


select top 2 * from custom_med_forms order by id asc