function createTaskPromise(taskName as string, fields = invalid as object, signalField = "output" as string) as object
    task = CreateObject("roSGNode", taskName)
    if fields <> invalid then task.setFields(fields)
    promise = __createPromiseFromNode(task, signalField)
    task.control = "run"
    return promise
end function

function createAnimationPromise(animation as object) as object
    promise = __createPromiseFromAnimation(animation)
    animation.control = "start"
    return promise
end function

function createObservablePromise(signalField as string, fields = invalid as object) as object
    node = CreateObject("roSGNode", "ContentNode")
    if fields <> invalid then node.addFields(fields)
    node.addField(signalField, "assocarray", false)
    promise = __createPromiseFromNode(node, signalField)
    return promise
end function

function createManualPromise()
    promise = __createPromise()
    promise.resolve = sub(val)
        m.context[m.id + "_callback"](val)
        m.complete = true
    end sub
    return promise
end function

'---------------------------------------------------------------------
' Everything below here is private and should not be called directly.
'---------------------------------------------------------------------
function __createPromiseFromNode(node as object, signalField as string) as object
    promise = __createPromise()
    node.id = promise.id
    node.observeField(signalField, "__nodePromiseResolvedHandler")
    promise.node = node
    return promise
end function

function __createPromiseFromAnimation(animation as object) as object
    promise = __createPromise()
    animation.id = promise.id
    animation.observeField("state", "__animationPromiseResolvedHandler")
    promise.animation = animation
    return promise
end function


function __createPromise() as object
    id = strI(rnd(2147483647), 36)
    promise = {
        then: function(callback as function)
           m.context[m.id + "_callback"] = callback
        end function
    }
    promise.context = m
    promise.id = id
    promise.complete = false
    m[id] = promise
    return promise
end function

sub __nodePromiseResolvedHandler(e as object)
    signalField = e.getField()
    node = e.getRoSGNode()
    id = node.id
    promise = m[id]
    promise.context[id + "_callback"](promise.node)
    promise.complete = true

    'clean up properly properly
    if promise.suppressDispose = invalid
        node.unobserveField(signalField)
        promise.delete("context")
        promise.delete("node")
        m.delete(id + "_callback")
        m.delete(id)
    end if
end sub

sub __animationPromiseResolvedHandler(e as object)
    
    signalField = e.getField()
    animation = e.getRoSGNode()
    Debug("__animationPromiseResolvedHandler {0}", animation.state)
    if(animation.state = "stopped")
      id = animation.id
      promise = m[id]
      promise.context[id + "_callback"](promise.animation)
      promise.complete = true

      'clean up properly properly
      if promise.suppressDispose = invalid
        animation.unobserveField(signalField)
        promise.delete("context")
        promise.delete("node")
        m.delete(id + "_callback")
        m.delete(id)
      end if
    end if
end sub
