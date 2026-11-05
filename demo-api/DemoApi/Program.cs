using System.Reflection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks().AddCheck<BreakableHealthCheck>("self");

var app = builder.Build();

app.UseHttpMetrics();

app.MapHealthChecks("/health");

app.MapGet("/version", () => Results.Json(new { version = ResolveVersion() }));

app.MapMetrics();

app.Run();

// DEMO_API_VERSION overrides the version baked in at build time.
static string ResolveVersion() =>
    Environment.GetEnvironmentVariable("DEMO_API_VERSION")
    ?? Assembly.GetExecutingAssembly()
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
    ?? "0.0.0-dev";

// Public so the tests can use WebApplicationFactory<Program>.
public partial class Program;

// Unhealthy when BreakHealth is set, to simulate a broken release.
internal sealed class BreakableHealthCheck(IConfiguration configuration) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var broken = configuration.GetValue<bool>("BreakHealth");

        return Task.FromResult(broken
            ? HealthCheckResult.Unhealthy("BreakHealth is set, so this release reports unhealthy on purpose.")
            : HealthCheckResult.Healthy());
    }
}
