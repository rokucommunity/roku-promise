# Roku-Promise
A Promise-like implementation for BrightScript/Roku

The benefit of this library is that it keeps your task-invocation and your task-result-handling code 
all together in one place instead of littering your code with observer handlers that make code
hard to follow.

## Usage

    createPromiseFromTask("TaskName", {
        input1: "some value",
        input2: 123
    }).then(function(task)
        results = task.output
        ' do other stuff here with the results.
        ' m is the original context from the caller
        m.label.text = results.text
    end function)

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
            createPromiseFromTask("TaskName", {}).then(function(task)
                ' m is available
                ' task is available
                ' val1, val2, and anotherVal are *not* available (they have different scope) 
            end function)
        end sub

    One work-around if you need to pass additional context to the callback is to pass the data as fields to the task:

        sub SomeFunction(val1, val2)
            anotherVal = val1 + val2
            createPromiseFromTask("TaskName", {
                val1: val1,
                val2: val2,
                anotherVal: anotherVal
            }).then(function(task)
                ' m is available
                ' task is available
                ' task.val1, task.val2, task.anotherVal are now all available
            end function)
        end sub

* By default, the signal field on the Task is `output` but you can pass an optional third parameter
with the name of a different field to observe for results.

        createPromiseFromTask("TaskName", {
            input1: "some value",
            input2: 123
        }, "items").then(function(task)
            items = task.items
        end function)

* This implementation is somewhat opinionated and *does not* support chained promises. So you *cannot* do this:

        createPromiseFromTask("TaskName", {}).then(callback).then(callback).then(callback)

    This is by design because it is rarely a good pattern to do a bunch of different tasks in serial like that.
Instead, it is usually better to have one Task that performs all of the necessary actions and returns
the final result to avoid multiple rendezvous. That said, if you do need to react to the results of a task with another task call, you can nest promise calls like this:

        createPromiseFromTask("TaskName", {}).then(function(task)
            results = task.output
            createPromiseFromTask("AnotherTask", {}).then(function(task)
                otherResults = task.output
                m.label.text = otherResults.text
            end function)
        end function)

* `createPromiseFromTask` returns the Promise object, so you dont have to call the `then` function immediately.
It is not usually necessary, but does allow for some advanced scenarios:

        promise = createPromiseFromTask("TaskName", {
            input1: "some value",
            input2: 123
        })
        '...do some other stuff with the promise
        promise.then(function(task)
            results = task.output
        end function)

* This creates a new Task each time. For most uses, that is the desired behavior. But for long-lived
tasks there is a slightly different approach. Instead of creating a new Task and observing a field on
the task, the alternative is to create a new `observable` (which is just a ContentNode) and *pass* that
to an existing task. When the task is done, it should set the appropriate field on the observable, which
will trigger the promise resolution. *Example of this will be added soon*

* The `whenAllPromisesComplete` function allows you to wait for all promises in a group to complete before
proceeding. Similar to above, this is usually not a desired/necessary pattern, but it was a fun academic
exercise for me to see if it could be done so I left the code in place for others to look at.
