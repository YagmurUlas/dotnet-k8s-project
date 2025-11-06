var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello World! My name is Yagmur Ulas Yucel. This is my .net web app.");

app.Run();
