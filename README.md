# Roku-Promise


[![build status](https://img.shields.io/github/actions/workflow/status/rokucommunity/roku-promise/build.yml?logo=github&branch=master)](https://github.com/rokucommunity/roku-promise/actions?query=branch%3Amaster+workflow%3Abuild)
[![monthly downloads](https://img.shields.io/npm/dm/roku-promise.svg?sanitize=true&logo=npm&logoColor=)](https://npmcharts.com/compare/roku-promise?minimal=true)
[![npm version](https://img.shields.io/npm/v/roku-promise.svg?logo=npm)](https://www.npmjs.com/package/roku-promise)
[![license](https://img.shields.io/github/license/rokucommunity/roku-promise.svg)](LICENSE)
[![Slack](https://img.shields.io/badge/Slack-RokuCommunity-4A154B?logo=slack)](https://join.slack.com/t/rokudevelopers/shared_invite/zt-4vw7rg6v-NH46oY7hTktpRIBM_zGvwA)

> [!CAUTION]
> This is a legacy project which is not under active development. Use [@rokucommunity/promises](https://github.com/rokucommunity/promises) instead which provides a much more robust promise solution.

This library helps making asynchronous logic simpler, by keeping invocation and result handling code
all together in one place instead of littering your code with observer handlers that make code
hard to follow.

**Disclaimer:** this only superficially looks like the JavaScript Promise API and is really only
a tool to observe Nodes and handle changes asynchronously.

## Installation

### Using ropm

```bash
ropm install roku-promise
```

### Manually

Copy `source/Promise.brs` into your project `source/` folder

## Basic Usage

```brightscript
createTaskPromise("TaskName", {
    input1: "some value",
    input2: 123
}).then(sub(task)
    results = task.output
    ' do other stuff here with the results.
    ' m is the original context from the caller
    m.label.text = results.text
end sub)
```

Behind the scenes, this is what happens:

* A new Task object is created
* Any properties provided are used to set the matching task fields
* A dynamic observer is set on the signal field
* The observer calls the `then` delegate, restoring the original scope/context

## API

### Task Promise

Create and run a task.

```brightscript
function createTaskPromise(taskName as string, fields = invalid as object, returnSignalFieldValue = false as boolean, signalField = "output" as string) as object
```

Arguments:

* `taskName` - Task Node to create
* `fields` - (optional) fields to set on the task
* `returnSignalFieldValue` - (optional) return observed field value instead of the task itself
* `signalField` - (optional) observed field name

### Animation Complete Promise

Wait for an animation to complete.

```brightscript
function createOnAnimationCompletePromise(animation as object, startAnimation = true as boolean, unparentNode = true as boolean) as object
```

Arguments:

* `animation` - an Animation node to observe
* `startAnimation` - (optional) start the animation
* `unparentNode` - (optional) detach the animation node when complete, if parented

Usage:

```brightscript
animation = m.top.animationName
createOnAnimationCompletePromise(animation, true, false).then(sub()
    ' animation completed!
    ' m is the original context from the caller
end sub)
```

### Resolved Promise

To return a deferred value using a Timer node.

```brightscript
function createResolvedPromise(value as dynamic, delay = 0.01 as float) as object
```

Arguments:

* `value` - payload of the Promise
* `delay` - (optional) in seconds

Usage:

```brightscript
createResolvedPromise(someData).then(sub(value)
    ' a few ms later, do something with the `value`
    ' m is the original context from the caller
end sub)
```

### Observable Promise

Create a Promise resolved by setting a Node field.

```brightscript
function createObservablePromise(signalFieldType = "assocarray" as string, fields = invalid as object, returnSignalFieldValue = false as boolean, signalField = "output" as string) as object
```

Arguments:

* `signalFieldType` - (optional) type of the field
* `field` - (optional) initial field values to set on the Node
* `returnSignalFieldValue` - (optional) return observed field value instead of the Node itself
* `signalField` - (optional) observed field name

Usage:

```brightscript
' setup
function create()
    promise = createObservablePromise()
    m.observedNode = promise.node
    return promise
end function

' caller
create().then(sub(node)
    ' do something with `node.output`
    ' m is the original context from the caller
end sub)

' later
m.observedNode.output = someData
```

### Promise from Node

Observe a Node field.

```brightscript
function createPromiseFromNode(node as object, returnSignalFieldValue as boolean, signalField as string) as object
```

Arguments:

* `node` - the Node context
* `returnSignalFieldValue` - return observed field value instead of the Node itself
* `signalField` - observed field name

Usage:

```brightscript
createPromiseFromNode(targetNode, "fieldName").then(sub(node)
    ' do something with `node.fieldName`
    ' m is the original context from the caller
end sub)
```

### Manual Promise

Create a Promise resolved by calling `resolve` on it (no Node involved).

```brightscript
function createManualPromise() as object
```

Usage:

```brightscript
' setup
function create()
    m.promise = createManualPromise()
    return m.promise
end function

' caller
create().then(sub(value)
    ' do something with `value`
    ' m is the original context from the caller
end sub)

' later
m.promise.resolve(someData)
```

## Features and limitations

* The important bit is that, in the `then` delegate, the context is the same as the original caller.
So if you call this from a Scene Graph component, `m` in the `then` delegate is the same `m` as the component.
This allows you to easily use the results of the task by setting UI fields.

* By the same token, since BrightScript does not have "capturing" closures, function-scoped variables are *not*
available in the 'then` callback. Consider:

    ```brightscript
    sub SomeFunction(val1, val2)
        anotherVal = val1 + val2
        createTaskPromise("TaskName", {}).then(sub(task)
            ' m is available
            ' task is available
            ' val1, val2, and anotherVal are *not* available (they have different scope)
        end sub)
    end sub
    ```

    One work-around if you need to pass additional context to the callback is to pass the data as fields to the task:

    ```brightscript
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
    ```

* This implementation *does not* support chained promises. So you *cannot* do this:

    ```brightscript
    ' NOT valid
    createTaskPromise("TaskName", {}).then(callback).then(callback).then(callback)
    ```

    If you do need to react to the results of a task with another task call, you can nest promise calls like this:

    ```brightscript
    createTaskPromise("TaskName", {}).then(sub(task)
        results = task.output
        createTaskPromise("AnotherTask", {}).then(sub(task)
            otherResults = task.output
            m.label.text = otherResults.text
        end sub)
    end sub)
    ```

* This implementation *does not* support multiple observers. So you *cannot* do this:

    ```brightscript
    ' NOT valid
    promise = createTaskPromise("TaskName", {})
    promise.then(callback1)
    promise.then(callback2) ' only last callback gets called
    ```

* This implementation *does not* support late observers. So you *cannot* do this:

    ```brightscript
    ' NOT valid
    promise = createManualPromise()
    promise.resolve(value)
    promise.then(callback) ' already resolved - won't be called
    ```

## Cook book

Although the most common use case is for spinning up, observing, and processing results from transient tasks, the
library can be used in some other more advanced scenarios as well.

### Accessing the underlying node

Node associated with a Promise can be accessed using their `.node` field.

```brightscript
promise = createResolvedPromise()
timer = promise.node
```

### Cancelling a Promise

Promises can be cancelled by calling their `.dispose()` method - associated Node will be unobserved and callback deleted.

```brightscript
' setup
m.promise = createTaskPromise("TaskName", {})

' cancellation
if m.promise.node <> invalid
    m.promise.node.control = "STOP"
    m.promise.dispose()
end if
```

### Long-lived Tasks

`createTaskPromise` creates a new Task each time it is called. For most uses, that is the desired behavior as it
is simply providing syntactic sugar over the create/observer/react pattern usually used with tasks.

You may want to (re)use a long-lived task. Those tasks usually has a `while` loop that is processing incoming events
on an `roMessagePort`.

The Promise library supports this pattern with the `createObservablePromise` method which should be used each time you
need to run a job. The Promise's Node can be passed to the task to provide configuration and return the result.

```brightscript
' create a receiver Promise with specific result type ("node", "array"...) and payload
promise = createObservablePromise("assocarray", { itemId: 1234 })
promise.then(sub(node)
    result = node.output
    '...do stuff with the result
end sub)

' trigger a job in long-lived task
m.global.longLivedTask.get = promise.node
```

And then in your task:

```brightscript
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
                observer.output = result
            end if
        end if
    end if
end while
```

### Repeated resolution

Usually, Promises can only be resolved once.

With this library you can set the `suppressDispose` flag (to a value `<> invalid`),
so the observers won't be automatically disposed and fire repeatedly.

```brightscript
' setup
m.observer = createPromiseFromNode(targetNode, "fieldName")
m.observer.suppressDispose = true
m.observer.then(sub(node)
    ' called on every change
end sub)

' cleanup
m.observer.dispose()
```
