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
-- здесь во временную таблицу заносим данные


declare @epmzname varchar(200), -- название формы (у типа ЭПМЗ максимальный размер 100, если название более 100 символов - оно обрежется, у формы - 200)
	@type varchar(20) = '', -- тип элемента
    @prefix varchar(100) = '', -- для meddescription и надписей перед элементами
	@groupname varchar(100) = '', -- реальное название группы
	@groupalias varchar(50) = '', -- псевдоним группы для наименования элементов
	@row int = 0, -- текущая строка в протоколе
	@column int = 0, -- текущий столбец в протоколе
	@height int = 0, -- высота элемента
	@width int = 0, -- ширина элемента
	@postfix varchar(50) = '', -- постфикс - это надпись, которая будет следовать после элемента
	@default varchar(1000) = '', -- дефолтное значение элемента
	@items varchar(2000) = '';

	@ex_groupalias varchar(50)= '', -- псевдоним прошлой группы
	@y int = 5, -- текущая координата по y (параметр top у элемента)
	@x int = 5, -- текущая координата по x (параметр left у элемента)
	@interval int = 5, -- стандартный интервал между элементами в форме, можно поменять по желанию
	@group_interval int = 10, -- стандартный интервал между группами, можно поменять по желанию
	@cur_column int = 0, -- текущий столбец
	@ex_column int = 0,
	@ex_row int = 0,
	@cur_row int = 0, -- текущая строка
	@FormContent xml, -- xml, которая будет на выходе
	@FormElement xml, -- кусок xml, который будет добавляться к @FormContent
	@elementName varchar(50); -- имя элемента

declare @FormContent xml = (SELECT -- инициализируем форму, здесь по желанию можно задать стандартный шрифт для протокола, рекомендуется courier new 12 размера, поскольку он monotype и можно посчитать интервалы
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
		if @groupalias <> @ex_groupalias -- если группа новая
		begin -- добавление заголовка группы, обновление column и row
			set @cur_column = 0;
			set @cur_row = 0;
			set @ex_row = 0;
			set @ex_column = 0;
			set @x = 0;
			set @y = @y + @group_interval;
		-- добавляем заголовок группы
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
			set @ex_groupalias = @groupalias; -- запомнаем текущую группу для следующей итерации
			set @y = @y + 18 + @interval; -- 18 - константа для шрфита courier new
		end;
		else -- если группа еще прошлая
		begin
			if @cur_row = @ex_row -- проверяем данный элемент, находится ли он на текущей строке или нет
			begin -- если да, двигаемся по X
				set @ex_column = @cur_column;
				set @cur_column = @cur_column + 1;
				set @x = @x + @interval;
			end;
			else -- если нет, то спускаемся вниз по Y
				set @ex_row = @cur_row;
				set @cur_row = @cur_row + 1;
				set @x = 5;
				set @y = @y + @interval;
			end;
		end;
		-- текстовое поле
		if @type = 'ТП' -- если текстовое поле, мы добавляем подпись к нему и дальше текстовое поле
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- надпсиь перед текстовым полем
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
				select dbo.make_memo_xml( -- само текстовое поле
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
		-- префикс перед строкой
		if @type in ('Строка', 'ВС')
		begin
			set @ElementName = dbo.make_element_name(@groupalias + 'Title', 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_label_xml( -- надпсиь перед текстовым полем
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
		-- Строка
		if @type = 'Строка'
		begin
			set @elementName = dbo.make_element_name(@groupalias, 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_text_edit_xml( -- само текстовое поле
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
		-- выпадающий список
		if @type = 'ВС'
		begin
			set @elementName = dbo.make_element_name(@groupalias, 0, @cur_column, @cur_row);
			set @FormElement = (
				select dbo.make_combobox_xml( -- само текстовое поле
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
		-- постфикс
		if @type in ('ВС', 'Строка')
		begin
			if @postfix <> '' -- добавляем постфикс после строки
			begin
				set @x = @x + len(@postfix) * 8;
				set @elementName = dbo.make_element_name(@groupalias, 1, @cur_column, @cur_row);
				set @FormElement = (
					select dbo.make_label_xml( -- надпсиь перед текстовым полем
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
@EpmzName = 'это пранк бро',
@EpmzGroupId = 1,
@FormName = 'это пранк бро',
@FormContent = @F,
@HtmlTemplate = '',
@ParamStr = '<?xml version="1.0" encoding="windows-1251"?><MEDPARAMSTR><paramStr><FORSTATIONAR>0</FORSTATIONAR><CODEPACS/><PRIVACYLEVEL>0</PRIVACYLEVEL><XCOMPONENTCOUNT>1</XCOMPONENTCOUNT></paramStr></MEDPARAMSTR>',
@OutParamStr = '';

-- при шрифте CourierNew 10 кегля ширина label на 1 символ - 8


select top 2 * from custom_med_forms order by id asc