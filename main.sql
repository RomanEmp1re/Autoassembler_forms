--if object_id('tempdb..#tmp_1') is not null
--   drop table [tempdb].[tmp_1];

-- это определение таблицы, в которую необходимо импортировать excel
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
-- здесь во временную таблицу заносим данные


-- select * from TestData



declare @epmzname varchar(200) = 'это пранк бро', -- название формы (у типа ЭПМЗ максимальный размер 100, если название более 100 символов - оно обрежется, у формы - 200)
	@type varchar(20) = '', -- тип элемента
    @prefix varchar(100) = '', -- для meddescription и надписей перед элементами
	@group int = -1, -- текущая группа
	@row int = 0, -- текущая строка в протоколе
	@column int = 0, -- текущий столбец в протоколе
	@height int = 0, -- высота элемента
	@width int = 0, -- ширина элемента
	@postfix varchar(50) = '', -- постфикс - это надпись, которая будет следовать после элемента
	@default varchar(1000) = '', -- дефолтное значение элемента
	@items varchar(2000) = ''; -- список элементов выпадающего списка

	declare @ex_groupname varchar(100)= '', -- имя прошлой группы
	@y int = 5, -- текущая координата по y (параметр top у элемента)
	@x int = 5, -- текущая координата по x (параметр left у элемента)
	@dy int = 5, -- стандартный интервал между элементами в форме, можно поменять по желанию
	@dy_group int = 30, -- стандартный интервал между группами, можно поменять по желанию
	@parentgroup int = -1,
	@group_col int = 0,
	@dx int = 5, -- стандартный интервал между элементами на строке
	@cur_col int = 0, -- текущий столбец
	@ex_col int = 0, -- прошлый столбец
	@ex_row int = 0, -- прошлая строка
	@cur_row int = 0, -- текущая строка
	@FormContent xml, -- xml, которая будет на выходе
	@FormElement xml, -- кусок xml, который будет добавляться к @FormContent
	@elementName varchar(50); -- имя элемента

set @FormContent = (
	SELECT -- инициализируем форму, здесь по желанию можно задать стандартный шрифт для протокола, рекомендуется courier new 12 размера, поскольку он monotype и можно посчитать интервалы
		'designform_frm' AS [form/@Name],
		'Экранная форма' AS [form/@Caption],
		'1049' AS [form/@Width],
		'891' AS [form/@Height],
		'-16777201' AS [form/@Color],
		'-16777208' AS [form/@Font.Color],
		'12' AS [form/@Font.Size],
		'Courier New' AS [form/@Font.Name],
		(-- так же добавляем сразу же большую надпись - название формы
			SELECT dbo.make_label_xml('FormTitle', @y, @x, @epmzname, 14)
			for xml path(''), type
		) AS [form],
		'' as [GroupsForPF],
		'<table>  </table>' AS [HtmlTemplate/@Content],
		'0' AS [HtmlTemplate/@StdTemplate]
	FOR XML PATH(''), ROOT('FormConstructor')
);
-- проходимся по элементам
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
		if @type = 'group' -- если элемент - заголовок группы
		begin -- добавление заголовка группы, обновление column и row
			set @cur_col = 0;
			set @cur_row = 0;
			set @ex_row = 0;
			set @ex_col = 0;
			set @group = @group + 1;
			set @x = 0;
			set @y = @y + @dy_group;
		-- добавляем заголовок группы
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
			set @y = @y + 20 + @dy_group; -- 20 - константа для шрифта courier new 14 кегля
		end;
		else -- если группа еще прошлая
		begin
			if @cur_row = @ex_row -- проверяем данный элемент, находится ли он на текущей строке или нет
			begin -- если да, двигаемся по X
				set @ex_col = @cur_col;
				set @cur_col = @cur_col + 1;
				set @x = @x + @dx;
			end;
			else -- если нет, то спускаемся вниз по Y
			begin
				set @ex_row = @cur_row;
				set @cur_row = @cur_row + 1;
				set @x = 5;
				set @y = @y + @dy;
			end;
		end;
		-- формируем имя элемента (позже надо будет добавить правило препинания)
		set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 0, 0)
		-- текстовое поле
		if @type = 'ТП' -- если текстовое поле, мы добавляем подпись к нему и дальше текстовое поле
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- надпись перед текстовым полем
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
				select dbo.make_memo_xml( -- само текстовое поле
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
		-- префикс перед строкой
		if @type in ('Строка', 'ВС', 'Дата')
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- надпсиь перед текстовым полем
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
		-- Строка
		if @type = 'Строка'
		begin
			set @FormElement = (
				select dbo.make_text_edit_xml( -- само текстовое поле
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
		-- выпадающий список
		if @type = 'ВС'
		begin
			set @FormElement = (
				select dbo.make_combobox_xml( -- само текстовое поле
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
		-- постфикс
		if @type in ('ВС', 'Строка') and @postfix <> ''
		begin
			set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 1, 0)
			set @x = @x + len(@postfix) * 12;
			set @FormElement = (
				select dbo.make_label_xml( -- надпсиь перед текстовым полем
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
@EpmzName = 'это пранк бро',
@EpmzGroupId = 1,
@FormName = 'это пранк бро',
@FormContent = @FormContent,
@HtmlTemplate = '',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';
*/
-- при шрифте CourierNew 10 кегля ширина label на 1 символ - 8

--delete from CUSTOM_MED_FORMS where name = 'это пранк бро'
--delete from epmz_types where name = 'это пранк бро'