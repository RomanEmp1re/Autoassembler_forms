create function dbo.make_group_name(
	@G int,
	@P int,
	@C int
)
returns varchar(30)
as begin
declare @result varchar(30) = 'G' + iif(@G > 9, cast(@G as varchar(2)), '0' + cast(@G as varchar(2)))
if @P >= 0
begin
	set @result = @result + 'P' + iif(@P > 9, cast(@P as varchar(2)), '0' + cast(@P as varchar(2)))
end
if @C > 0
begin
	set @result = @result + 'C' + iif(@C > 9, cast(@C as varchar(2)), '0' + cast(@C as varchar(2)))
end
return @result
end

