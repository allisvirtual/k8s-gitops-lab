using System.Reflection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks().AddCheck<BreakableHealthCheck>("self");

var app = builder.Build();

// Counts and times every request, so /metrics has something to report.
app.UseHttpMetrics();

// Liveness and readiness for the Kubernetes probes.
app.MapHealthChecks("/health");

// The endpoint the measurement scripts poll to see that a release is live.
app.MapGet("/version", () => Results.Json(new { version = ResolveVersion() }));

// Prometheus scrape target.
app.MapMetrics();

app.Run();

// DEMO_API_VERSION wins so that Helm can set the version without a rebuild.
// Otherwise the value baked in at build time is used.
static string ResolveVersion() =>
    Environment.GetEnvironmentVariable("DEMO_API_VERSION")
    ?? Assembly.GetExecutingAssembly()
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
    ?? "0.0.0-dev";

// Top-level statements compile to an internal Program class. This makes it
// public so the test project can use WebApplicationFactory<Program>.
public partial class Program;

/// <summary>
/// Healthy unless BreakHealth is set. Setting it is how the recovery
/// measurement gets a deliberately broken release to recover from.
/// </summary>
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
