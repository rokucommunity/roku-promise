# Roku-Promise
A Promise-like implementation for BrightScript/Roku

![build](https://github.com/rokucommunity/roku-promise/workflows/build/badge.svg)

The benefit of this library is that it keeps your task-invocation and your task-result-handling code 
all together in one place instead of littering your code with observer handlers that make code
hard to follow.

## Installation
### Using ropm
```bash
ropm install roku-promise
```
### Manually
Copy `source/Promise.brs` into your project `source/` folder

## Basic Usage

    createTaskPromise("TaskName", {
        input1: "some value",
        input2: 123
    }).then(sub(task)
        results = task.output
        ' do other stuff here with the results.
        ' m is the original context from the caller
        m.label.text = results.text
    end sub)

Behind the scenes, this is what happens:
* A new Task object is created
* Any properties provided are used to set the matching task fields
* A dynamic observer is set on the signal field
* When the task is complete, it sets the signal field, which triggers the observer
* The observer calls the `then` delegate, restoring the original scope/context

## Important Notes

* The important bit is that, in the `then` delegate, the context is the same as the original caller.
So if you call this from a Scene Graph component, `m` in the `then` delegate is the same `m` as the component.
This allows you to easily use the results of the task by setting UI fields.

* By the same token, since BrightScript does not have "capturing" closures, function-scoped variables are *not*
available in the 'then` callback. Consider:

        sub SomeFunction(val1, val2)
            anotherVal = val1 + val2
            createTaskPromise("TaskName", {}).then(sub(task)
                ' m is available
                ' task is available
                ' val1, val2, and anotherVal are *not* available (they have different scope) 
            end sub)
        end sub

    One work-around if you need to pass additional context to the callback is to pass the data as fields to the task:

        sub SomeFunction(val1, val2)
            anotherVal = val1 + val2
            createTaskPromise("TaskName", {
                val1: val1,
                val2: val2,
                anotherVal: anotherVal
            }).then(sub(task)
                ' m is available
                ' task is available
                ' task.val1, task.val2, task.anotherVal are now all available
            end sub)
        end sub

* By default, the signal field on the Task is `output` but you can pass an optional third parameter
with the name of a different field to observe for results.

        createTaskPromise("TaskName", {
            input1: "some value",
            input2: 123
        }, "items").then(sub(task)
            items = task.items
        end sub)

* This implementation is somewhat opinionated and *does not* support chained promises. So you *cannot* do this:

        createTaskPromise("TaskName", {}).then(callback).then(callback).then(callback)

    This is by design because it is rarely a good pattern to do a bunch of different tasks in serial like that.
Instead, it is usually better to have one Task that performs all of the necessary actions and returns
the final result to avoid multiple rendezvous. That said, if you do need to react to the results of a task with another task call, you can nest promise calls like this:

        createTaskPromise("TaskName", {}).then(sub(task)
            results = task.output
            createTaskPromise("AnotherTask", {}).then(sub(task)
                otherResults = task.output
                m.label.text = otherResults.text
            end sub)
        end sub)

## Advanced Usage

Although the most common use case is for spinning up, observing, and processing results from transient tasks, the
library can be used in some other more advanced scenarios as well.

### Saving Promise References

`createTaskPromise` returns the Promise object, so you dont have to call the `then` function immediately.
It is not usually necessary, but does allow for some advanced scenarios:

        promise = createTaskPromise("TaskName", {
            input1: "some value",
            input2: 123
        })
        '...do some other stuff with the promise
        promise.then(sub(task)
            results = task.output
        end sub)

One use case for this is to save a reference to the promise in a lookup dictionary so that you can track multiple
in-flight promises.

### Long-lived Tasks

`createTaskPromise` creates a new Task each time it is called. For most uses, that is the desired behavior as it
is simply providing syntactic sugar over the create/observer/react pattern usually used with tasks.
Some actions are more appropriate for long-lived tasks however, where the task is created only once and exists
for the lifetime of the app. In these cases, the task usually has a `while` loop that is processing incoming events
on an `roMessagePort`. One strategy for returning the results is to use `node` type fields on the task: the calling
thread can create the node and observe a field that will hold the results, then that entire node is passed to the task.
When the task has processed the request, it sets the node's field which trigger the observer back in the calling thread.

The Promise library supports this pattern with the `createObservablePromise` method. You specify the name of your
signaling field (and optionally, any other fields that you would like to add to the node) and the library will handle
wiring up the promise handler to your node. Pass the node to your task, have the task set the signal field when it
is done, and your `then` function will automatically get invoked. This also implicitly solves the issue of tracking
which response from the long-lived task goes with with request - it 'just works'.

    p = createObservablePromise("result", {itemId: 1234})
    longLivedTask = m.global.longLivedTask
    longLivedTask.get = promise.node
    p.then(sub(node)
        result = node.result
        '...do stuff with the result
    end sub)

And then in your task:

    while true
        msg = wait(0, m.port)
        if msg <> invalid
            msgType = type(msg)
            if msgType = "roSGNodeEvent"
                field = msg.getField()
                observer = msg.getData()
                if field = "get"
                    '...do some stuff (make network calls, create ContentNodes, etc)
                    result = DoStuff(observer.itemId)
                    observer.result = result
                end if
            end if
        end if
    end while

### Manual Promises

Both `createTaskPromise` and `createObservablePromise` are automatically resolved when their signaling field is set, but
you can also create a 'manual' promise using `createManualPromise`. This will return a promise with a `resolve`
method that you can call at any later time to trigger the `then` callback. A contrived example:

    p = createManualPromise()
    p.then(sub(val)
        ?"manual promise resolved with val", val
    end sub)

    '...do a bunch of other stuff in your app

    ' then, sometime later (perhaps in response to user input, timer, etc)...
    p.resolve(5)

*(Note: I am not entirely sure of the usefulness of this functionality, but it was easy to include and thought
it might be interesting to see what use cases other folks came up with for it.)*

### Build-Your Own

Lastly, you can use the 'private' `__createPromiseFromNode` or `__createPromise` methods to build your own custom types
of promises on top of the core built-in functionality. Some possible ideas (not all of which are probably *good* ideas):

* Add `catch`-like semantics for handling errors from tasks by observing an additional error signal field
* Wrap a timer in a promise so that your callback is triggered after a time period
* Build a `whenAll` function to wait for multiple promises
* Create a `promisify` method to make anything into a promise
* Add advanced promise functionality like `join`, etc
