function createTaskPromise(taskName as string, returnSignalFieldValue = true as boolean, fields = invalid as object, signalField = "output" as string) as object
    task = CreateObject("roSGNode", taskName)
    if fields <> invalid then task.setFields(fields)
    promise = __createPromiseFromNode(task, signalField)
    promise.returnSignalFieldValue = returnSignalFieldValue
    task.control = "run"
    return promise
end function

function createObservablePromise(signalFieldType = "assocarray" as string, returnSignalFieldValue = true as boolean, fields = invalid as object, signalField = "output" as string) as object
    node = CreateObject("roSGNode", "Node")
    if fields <> invalid then node.addFields(fields)
    node.addField(signalField, signalFieldType, false)
    promise = __createPromiseFromNode(node, signalField)
    promise.returnSignalFieldValue = returnSignalFieldValue
    return promise
end function

function createManualPromise() as object
    promise = __createPromise()
    promise.resolve = sub(value)
        m.context[m.id + "_callback"](value)
        m.complete = true
    end sub
    return promise
end function

function createOnAnimationCompletePromise(animation as object, startAnimation = true as boolean, unparentNode = true as boolean) as object
    promise = __createPromiseFromNode(animation, "state")
    promise.shouldSendCallback = function(node) as Boolean
        if node.state = "stopped" then return true
        return false
    end function
    promise.unparent = unparentNode

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
    promise.signalField = signalField
    promise.node = node
    return promise
end function

function __createPromise() as object
    id = StrI(rnd(2147483647), 36)
    promise = {
        then: sub(callback as function)
            m.context[m.id + "_callback"] = callback
        end sub

        dispose: sub()
            if m.complete = true then return
            m.context.delete(m.id + "_callback")
            m.context.delete(m.id)
            m.node.unobserveFieldScoped(m.signalField)
            m.delete("context")
            m.delete("node")
        end sub
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
    if isFunc(callback) then
        if promise.returnSignalFieldValue = true then
            callback(promise.node[promise.signalField])
        else
            callback(promise.node)
        end if
    end if

    'clean up properly properly
    if promise.suppressDispose = invalid then
        promise.dispose()
    end if

    promise.complete = true

    if promise.unparent = true then
        parent = node.getParent()
        if parent <> invalid then parent.removeChild(node)
    end if
end sub
