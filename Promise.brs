function createTaskPromise(taskName as string, fields = invalid as object, signalField = "output" as string) as object
    task = CreateObject("roSGNode", taskName)
    if fields <> invalid then task.setFields(fields)
    promise = __createPromiseFromNode(task, signalField)
    task.control = "run"
    return promise
end function

function createObservablePromise(signalFieldType = "assocarray" as string, fields = invalid as object, signalField = "output" as string) as object
    node = CreateObject("roSGNode", "Node")
    if fields <> invalid then node.addFields(fields)
    node.addField(signalField, signalFieldType, false)
    promise = __createPromiseFromNode(node, signalField)
    return promise
end function

function createManualPromise() as object
    promise = __createPromise()
    promise.resolve = sub(val)
        m.context[m.id + "_callback"](val)
        m.complete = true
    end sub
    return promise
end function

function createOnAnimationCompletePromise(animation as object, startAnimation = true as boolean, unparent = true as boolean) as object
    promise = __createPromiseFromNode(animation, "state")
    promise.shouldSendCallback = function(node) as Boolean
        if node.state = "stopped" then return true
        return false
    end function
    promise.unparent = true

    if startAnimation then animation.control = "start"
    return promise
end function


'---------------------------------------------------------------------
' Everything below here is private and should not be called directly.
'---------------------------------------------------------------------
function __createPromiseFromNode(node as object, signalField as string) as object
    promise = __createPromise()
    node.id = promise.id
    node.observeFieldScoped(signalField, "__nodePromiseResolvedHandler")
    promise.node = node
    return promise
end function

function __createPromise() as object
    id = StrI(rnd(2147483647), 36)
    promise = {
        "then": function(callback as function)
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

    isFunc = function (value)
        valueType = type(value)
        return (valueType = "roFunction") or (valueType = "Function")
    end function

    if isFunc(promise.shouldSendCallback) and promise.shouldSendCallback(node) = false then return

    callback = promise.context[id + "_callback"]
    if isFunc(callback) then callback(promise.node)

    promise.complete = true

    'clean up properly properly
    if promise.suppressDispose = invalid then
        node.unobserveFieldScoped(signalField)
        promise.delete("context")
        promise.delete("node")
        m.delete(id + "_callback")
        m.delete(id)
    end if

    if promise.unparent = true then
        parent = node.getParent()
        if parent <> invalid then parent.removeChild(node)
    end if
end sub
