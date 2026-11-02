using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DemoApi.Tests;

public class EndpointTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task Health_is_healthy_by_default()
    {
        var response = await factory.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Health_fails_when_BreakHealth_is_set()
    {
        var broken = factory.WithWebHostBuilder(builder => builder.UseSetting("BreakHealth", "true"));

        var response = await broken.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Version_reports_a_version()
    {
        var response = await factory.CreateClient().GetAsync("/version");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var version = body.RootElement.GetProperty("version").GetString();

        Assert.False(string.IsNullOrWhiteSpace(version));
    }

    [Fact]
    public async Task Metrics_are_exposed_in_Prometheus_format()
    {
        var response = await factory.CreateClient().GetAsync("/metrics");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.StartsWith("text/plain", response.Content.Headers.ContentType?.MediaType ?? string.Empty);
        Assert.Contains("# HELP", await response.Content.ReadAsStringAsync());
    }
}
