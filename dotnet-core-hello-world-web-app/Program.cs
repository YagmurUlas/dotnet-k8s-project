var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello World! My name is Yagmur. This is my .net web app. Jenkins trigger is working.");

app.Run();
