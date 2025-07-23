declare
	@default_width int = 900;

declare -- первичное преобразование, анализ и проверка правильности заполнения
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

-- подготовка таблицы к расчетам
insert into @elements
select
	id,
	case structure
		when 'заголовок' then 'header'
		when 'подпись' then 'postfix'
	end as structure,
	case [type]
		when 'ТП' then 'Memo'
		when 'ВС' then 'ComboBox'
		when 'строка' then 'Edit'
		when 'надпись' then 'Label'
		else 'Неизвестный элемент'
	end as type,
	prefix,
	row,
	row_number() over (partition by row order by id) - 1 as col,
	case [type]
		when 'ТП' then case
			when cnt_str > 0 then cnt_str
			else 1
		end
		else 0
	end as cnt_str,
	case
		when type = 'ТП' then @default_width
		when type =  'Label' then len(prefix) * 8 -- рассчитываем ширину надписи, чтобы потом отмерять интервалы
		else width
	end as width,
	isnull([default], '') as [default],
	case [type]
		when 'ВС' then case
			when items is not null then items
			else 'да'+char(10)+'нет'
		end
		else null
	end as items,
	case -- признак того, что надпись является последней в строке
		when structure = 'группа' then null
		when 
			lead([row]) over (order by id) <> [row] -- следующая строка имеет другой номер
			or lead(structure) over (order by id) = 'группа' -- или следующий элемент - группа
			or lead(id) over (order by id) is null -- или это вообще последний элемент во всем протоколе
		then 1
		else 0
	end as is_last_in_row
from TestData$
where id > 0
	and (row > 0 or structure = 'заголовок')

select * from @elements

declare 
	@epmzname varchar(200) = 'это пранк бро', -- название формы (у типа ЭПМЗ максимальный размер 100, если название более 100 символов - оно обрежется, у формы - 200)
	@type varchar(20) = '', -- тип элемента
    @prefix varchar(100) = '', -- для meddescription и надписей перед элементами
	@G int = -1, -- текущая группа
	@row int = 0, -- текущая строка в протоколе
	@column int = 0, -- текущий столбец в протоколе
	@height int = 0, -- высота элемента
	@width int = 0, -- ширина элемента
	@postfix varchar(50) = '', -- постфикс - это надпись, которая будет следовать после элемента
	@default nvarchar(4000) = '', -- дефолтное значение элемента
	@labelcount int = 0,
	@items nvarchar(4000) = '', -- список элементов выпадающего списка
	@structure varchar(10),
	@fontstyle varchar(30),
	@fontsize int,
	@is_last_in_row bit = 0;

	declare @ex_groupname varchar(100)= '', -- имя прошлой группы
	@y int = 5, -- текущая координата по y (параметр top у элемента)
	@x int = 5, -- текущая координата по x (параметр left у элемента)
	@startx int = 5, -- отступ слева
	@dy int = 5, -- стандартный интервал между элементами в форме, можно поменять по желанию
	@dy_group int = 10, -- стандартный интервал под группами, можно поменять по желанию
	@parentgroup int = -1,
	@group_col int = 0,
	@dx int = 5, -- стандартный интервал между элементами на строке
	@C int = 0, -- текущий столбец
	@exR int = -1, -- прошлая строка
	@R int = 0, -- текущая строка
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
			SELECT dbo.make_label_xml('FormTitle', @y, @x, @epmzname, 14, 'fsBold')
			for xml path(''), type
		) AS [form],
		'' as [GroupsForPF],
		'<table>  </table>' AS [HtmlTemplate/@Content],
		'0' AS [HtmlTemplate/@StdTemplate]
	FOR XML PATH(''), ROOT('FormConstructor')
);
set @y = @y + 22; -- 22 - константа для 14 шрифта
-- проходимся по элементам
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
where type in ('ВС', 'ТП', 'строка', 'группа')
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
		-- определяем имена
		if @structure = 'group' -- если элемент - заголовок группы
		begin -- добавление заголовка группы, обновление column и row, x и y
			set @G = @G+ 1;
			set @elementName = dbo.make_group_name(@G, @parent_group, @group_col);
			set @fontstyle = 'fsBold';
		end;
		if @structure = 'postfix'
		begin
			set @fontstyle = '';
			set @elementName = dbo.make_element_name(@G, @R, @C, 1, 0);
		end
		-- имя очередного обычного элемента
		if @structure is null
		begin	
			set @fontstyle = '';
			set @elementName = dbo.make_element_name(@G, @R, @C, 0, 0);
		end

		-- добавляем элемент

		if @type = 'Label'
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- надпись перед текстовым полем
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

		if @type = 'ТП' -- если текстовое поле, мы добавляем подпись к нему и дальше текстовое поле
		begin
			set @FormElement = (
				select dbo.make_label_xml( -- надпись перед текстовым полем
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
			set @y = @y + 18 + @dy; -- 18 - костанта для 12 шрифта
			set @FormElement = (
				select dbo.make_memo_xml( -- само текстовое поле
					@y, 
					@x, 
					900, 
					@cnt_str * 18 + 8, -- уравнение нахождения высоты ТП зная кол-во строк при шрифте courier new
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
			if @cur_row = @ex_row -- проверяем данный элемент, находится ли он на текущей строке или нет
			begin -- если да, двигаемся по X
				set @cur_col = @cur_col + 1
				set @ex_col = @cur_col;
				set @x = @x + @dx;
			end;
			else -- если нет, то спускаемся вниз по Y
			begin
				set @ex_row = @cur_row;
				set @cur_col = 0;
				set @x = @startx;
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
			set @y = @y + 18 + @dy; -- 18 - костанта для 12 шрифта
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
			set @x = @x + @width;
			set @labelcount = @labelcount + 1
			if @is_last_in_row = 1 
			begin
				set @y = @y + 26; -- константа для строк и вс пи 12 шрифте
			end;
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
			set @x = @x + @width;
			if @is_last_in_row = 1 
			begin
				set @y = @y + 26; -- константа для строк и вс пи 12 шрифте
			end;
		end;
		-- постфикс
		if @type in ('ВС', 'Строка') and @postfix <> ''
		begin
			set @elementName = dbo.make_element_name(@group, @cur_row, @cur_col, 1, 0)
			set @x = @x + len(@postfix) * 12;
			set @FormElement = (
				select dbo.make_label_xml( -- надпсиь перед текстовым полем
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