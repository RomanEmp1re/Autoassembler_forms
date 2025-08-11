alter function dbo.make_element_name(
	@G int,
	@R int,
	@C int,
	@D int,
	@N int
)
returns varchar(30)
as begin
declare @result varchar(30) = 'R' + iif(@R > 9, cast(@R as varchar(2)), '0' + cast(@R as varchar(2)))
if @G >= 0
begin
	set @result = 'G' + iif(@G > 9, cast(@G as varchar(2)), '0' + cast(@G as varchar(2))) + @result
end
if @C > 0
begin
	set @result = @result + 'C' + iif(@C > 9, cast(@C as varchar(2)), '0' + cast(@C as varchar(2)))
end
if @D > 0
begin
	set @result = @result + 'D' + iif(@D > 9, cast(@D as varchar(2)), '0' + cast(@D as varchar(2)))
end
if @N >= 0
begin
	set @result = @result + 'N' + iif(@N > 9, cast(@N as varchar(2)), '0' + cast(@N as varchar(2)))
end
return @result
end

