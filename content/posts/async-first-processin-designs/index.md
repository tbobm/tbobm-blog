+++
title = 'Asynchronous first design for processing'
date = 2025-05-02T14:55:20+02:00
ShowToc = true
tocopen = false
tags = ['tech', 'design', 'architecture', 'async']
+++


## Intro

Define synchronous (HTTP communication, Service mesh like Istio, answer directly to client)
vs asynchronous processing (Queues, Asynchronous service mesh like Pauline, answer using callback or polling)

## Comparing both setup

Todo app, micro API, containerized
- CRUD for todos

### Sync

- lightweight operations with fast feedback
- quick to proceed
- write directly to database

### Async

- lightweight operations leads to overhead
- quick to proceed
- decouple queuing, need to refresh state

## Adding a feature, video upload

- long-running operation 
- requires lot of processing and I/O
- can lead to errors

### Sync

- longer requests impact horizontal processing capacity
- storing video in s3 is costly
- 

### Async

- synchronous operations can be moved
- generate presigned URL and only use this as a reference

## Conclusion

Feel free to reach out if you have feedback or questions !

[Theo "Bob" Massard][linkedin]

[linkedin]: https://linkedin.com/in/tbobm/

[db-bootstrapping-repo]: https://github.com/tbobm/bootstrapping-databases
