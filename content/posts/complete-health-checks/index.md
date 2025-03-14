+++
title = 'Complete health checks and why they matter'
date = 2025-03-11T11:30:20+02:00
ShowToc = true
tocopen = false
tags = ['tech', 'reliability', 'optimization']
+++

Standard health checks tell you if an app is running but not if it’s actually working.
**Complete Health Checks** go deeper, verifying dependencies like databases and caches to catch issues early and keep deployments smooth.

In this article, we’ll cover why they matter, how to set them up,
and the key differences between liveness and readiness checks—so your services stay reliable and efficient in production.

# What are health checks and why are they so useful

Having an application that performs some kind of processing is only the first part of the journey.
Once in production, it's quite impossible to _fly blind_ and just hope that everything works.
To address this need, we can introduce a utility feature that exposes the status of our application using a health check.

At first, we can setup a health check like the one we often see in most APIs: `/health`.

The `/health` route is expected to answer a 2XX status code and translates into the API saying:
> I'm **alive** and able to receive HTTP requests!

Using a mock API, we can try this route using [`curl`][curl]:

{{< highlight bash-session "linenos=false" >}}
$ curl http://localhost/health
{"message": "alive!"}
{{< / highlight >}}

We usually set those in many shape or forms but we'll stick to Python to match
our example:

{{< highlight python "linenos=table" >}}
@app.route("/health")
def health_check():
    return {"message": "alive!"}
{{< / highlight >}}

However, being able to to receive HTTP requests is one thing, processing them successfully is another,
more advanced topic.

I already wrote about this in my article on Black-box monitoring (see [Black-box monitoring at Diffusely using k6][tbobm-blackbox-monitoring]), there are plenty of ways to prevent our API clients from
being the first entities that will discover that something is wrong in our applications.

Ever discovered upon testing a new deployment that the `DATABASE_URL` wasn't properly set ?

**Complete Health Checks** might be just the right thing!

[tbobm-blackbox-monitoring]: https://medium.diffuse.ly/black-box-monitoring-at-meero-using-k6-50ff79800cbc

## Introducing: "Complete" health checks 

The goal of the Complete Health Check pattern is to expose the status
of _3rd party dependencies_ [^1]. This would mean that observers and coordinators
like monitoring or orchestration services.
They aim to be an **additional source of information** that target deployments of new versions of an app.

[^1]: In regard to our application's code, here we consider **3rd party application** anything that
we interact with and that we would want to test, such as Databases, Message Brokers, ....

Not to be a replacement of standard availability health checks as they answer different question.
Distributed systems where [east-west traffic][east-west-wiki] happen a lot are most suited for this
as failure to answer perfectly, at scale, could impact the overall performances of the system.

[east-west-wiki]: https://en.wikipedia.org/wiki/East-west_traffic

## Expected benefits

Complete Health Checks go beyond the simple [HTTP 200][http-200] response by actively verifying the availability
and functionality of key system dependencies. This deeper validation provides several advantages,
especially in environments where reliability and efficiency are critical.

In a microservice based architecture, they help preventing cascading outages and keep
the retry capabilities for more complex situations.

[http-200]: https://http.cat/status/200

### Integrate the Fail-Fast Concept in Deployments

By proactively detecting failures before they impact users, Complete Health Checks help
implement the [fail-fast principle][wiki-failfast] in new deployments. If a crucial dependency is
unreachable, the deployment can be cancelled and rolled back immediately, reducing the risk of degraded service.

- **Database Connectivity Issues**: If an application can not connect to its database, it must fail
as early as possible instead of attempting to serve requests that will fail anyway.
- **External Service Availability**: Some applications rely on third-party APIs or internal services.
A proper health check should validate access to these endpoints to ensure smooth operation.

### Guarantee Processing Efficiency During Deployments

A system that is aware of its own health can make smarter decisions about request handling.
Instead of blindly accepting traffic,
it can gracefully reject requests [^2] if a key component is unavailable.

[^2]: This can be handled at the [service mesh][wiki-service-mesh] level if any

- **Serve Only Valid Requests**: If the application detects missing dependencies, it can return an appropriate error status instead of inefficiently processing doomed requests.
- **Optimize Resource Utilization**: Prevent wasted resources in production by ensuring that only healthy instances handle user traffic. This goes a long way towards [green IT][wiki-green-it] and cost reduction for processing
heavy requests.

### Expose More Than Just Basic Availability

Basic health checks only confirm whether an application is running, but Complete Health Checks provide deeper insights into system health.

- **Instant Cache Status Visibility**: A well-implemented health check can report if cache layers (e.g., Redis, Memcached)
are operational, helping diagnose performance bottlenecks.
- **Granular System Insights**: Instead of a binary "up or down" status, a more granular health check endpoint can return structured
data about application health, making it easier to debug issues before they escalate.

## How to set them up

As a proper, hands-on example, let's consider the following application:
- Small API using [FastAPI][fastapi-home]
- Caching using [Redis][redis-home]
- Backend database storage using [postgresql][postgresql-home]

It translates into the following diagram:

![architecture diagram](./api-diagram.png#center)

Here, the API will use the cache to reduce the stress on our database and
third party calls.

To properly implement a Complete Health Check, we need to ensure that
we can reach both our Redis and our PostgreSQL dependencies.

- Redis: performing a [`ping`][redis-ping] command.
- PostgreSQL: executing a `SELECT 1;` statement against our database.

{{< highlight python "linenos=table" >}}
def perform_full_healthcheck() -> bool:
    # ensure redis can be reached
    redis_client.ping()

    # ensure postgres can be reached and we have read permission
    with psycopg2.connect(DB_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
    return True
{{< /highlight >}}

We can proceed to include our complete health check as another route in our application:

{{< highlight python "linenos=table" >}}
@app.route("/health-full")
def perform_health_check():
    try:
        complete_check_successful = perform_full_healthcheck()
        return {"message": "full health check works!"}
    except Exception as err:  # something went wrong
	# we have to return any non-2XX status code
        return {"message": "full health check does not work"}, 500
{{< / highlight >}}

Most of the services only support a single strategy for health checks, meaning that for a
given "health check" initiator (i.e.: [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)),
which means that:
1. we don't want to spam our database or cache instance
2. once the "full setup" is done, we can switch to the default "serve requests" check

This can be implemented using the following pattern:

{{< highlight python "linenos=table" >}}
@app.route("/health")
def perform_health_check():
    if full_health_check_performed:
        return {"message": "simple health check works!"}
    complete_check_successful = perform_full_healthcheck()
    if complete_check_successful:
        full_health_check_performed = True
    return {"message": "full health check works!"}
{{< / highlight >}}

In the above snippet, we assume that we use global variables to simplify
switching between readiness and healthiness when using the same endpoint.

> _Ideally we use 2 distinct endpoints but some orchestration services only
allow a single endpoint to be tested for healthiness._


## Liveness vs readinesss

Health checks in modern cloud environments typically fall into two categories: **liveness checks** and **readiness checks**. Understanding the distinction is crucial when designing a robust health check strategy.  

**Liveness Checks: Ensuring the Application is Running**  
A **liveness check** determines whether the application process is alive and capable of serving requests. This is what most standard health checks do—they simply confirm that the service is reachable and responding to HTTP requests.  

- Used by **load balancers**, **orchestrators** (ECS, Kubernetes), and **service meshes** to determine whether a container should continue running.  
- If a liveness check fails, the container is typically restarted.  
- Examples:  
  - Responding with an HTTP 200 status from a `/health` endpoint.  
  - Checking if the process is still running using a command like `pgrep my-service`.  

**Readiness Checks: Ensuring the Application is Ready to Handle Traffic**  
A **readiness check** is a more advanced health check that verifies whether the application is fully initialized and ready to serve traffic. It does not just check if the process is running but also ensures all dependencies (database, cache, external APIs) are in a good state.  

- Used by **load balancers**, **Kubernetes probes**, and **container orchestrators** to determine when an instance should start receiving traffic.  
- Unlike liveness checks, failing a readiness check does not trigger a restart—it simply removes the instance from the traffic pool.  
- Examples:  
  - Checking if the database connection is live before marking the service as ready.  
  - Validating access to an external API or cache system.  

**Complete Health Check: A Readiness Check for Real-World Deployments**  
A **Complete Health Check** is effectively a readiness check that goes beyond simple "reachability" checks. Instead of just verifying if the application is running, it ensures the service is in a state where it can properly handle requests.  

- **Best used for validating configurations and dependencies before accepting traffic.**  
- Can be implemented at the **container image level** using an entry point script or a dedicated health check.  
- Ensures that misconfigured or partially initialized instances do not serve traffic.  

**Implementation Examples (ECS, Kubernetes)**  
Complete Health Checks can be integrated into common cloud environments like ECS and Kubernetes.

Here we consider the `/health` route to return the standard health check and the `/health-full`
acts as the complete health check.

**Kubernetes:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health-full
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```
- The liveness probe ensures the container is running.  
- The readiness probe ensures the container is ready before accepting traffic.  

_Check the corresponding [Kubernetes documentation on Liveness, Readiness (and Startup) probes][k8s-probes]._

**AWS ECS (Fargate/EC2-backed tasks):**

```json
"healthCheck": {
  "command": [
    "CMD-SHELL",
    "curl -f http://localhost:8080/health-full || exit 1"
  ],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 10
}
```
- The ECS task only joins the service once it passes the readiness check.  
- A failing readiness check removes the task from the load balancer without restarting it.  

_Feel free to check [the dedicated documentation][ecs-health] for a deeper understanding of how health checks
work in ECS._

**Combining Multiple Health Check Sources**:

Complete Health Checks provide more granular health insights, making them valuable
for multiple system components:  

- **Load Balancer (ALB, NLB, API Gateway)**: Uses health checks to determine if an instance should receive traffic.  
- **Container Orchestrator (Kubernetes, ECS)**: Uses readiness probes to decide when an instance is ready for service.  
- **ECS Task-Level Health Check**: Ensures that only fully configured instances join the service.  

By leveraging both **liveness** and **readiness** checks correctly,
applications can achieve higher availability, prevent misconfigured
deployments, and optimize request handling.  

## Conclusion

Implementing both liveness and readiness checks ensures that your application
remains not just available, but fully operational and efficient.
This approach helps catch misconfigurations early, optimizes resource
usage, and prevents unnecessary downtime.

No matter the deployment platform [Kubernetes][k8s], [ECS][ecs] or anything that
supports health checks integrating these checks strengthens
reliability and predictability.

Want to see a minimal implementation? Check it out here: [complete-health-checks-design][health-check-repo]

Feel free to reach out if you have feedbacks or questions !

[Theo "Bob" Massard][linkedin]

[linkedin]: https://linkedin.com/in/tbobm/

[health-check-repo]: https://github.com/tbobm/complete-health-checks-design

[redis-ping]: https://redis.io/docs/latest/commands/ping/
[wiki-failfast]: https://en.wikipedia.org/wiki/Fail-fast_system#Hardware_and_software
[curl]: https://curl.se

[alb-healthcheck]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html

[fastapi-home]: https://fastapi.tiangolo.com/
[redis-home]: https://redis.io/docs/latest/
[postgresql-home]: https://www.postgresql.org/
[k8s]: https://kubernetes.io/
[ecs]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html
[ecs-health]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/healthcheck.html
[k8s-probes]: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
[wiki-service-mesh]: https://en.wikipedia.org/wiki/Service_mesh
[wiki-green-it]: https://en.wikipedia.org/wiki/Green_computing
