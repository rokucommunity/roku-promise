function createTaskPromise(taskName as string, fields = invalid as object, returnSignalFieldValue = false as boolean, signalField = "output" as string) as object
    task = CreateObject("roSGNode", taskName)
    if fields <> invalid then task.setFields(fields)
    promise = createPromiseFromNode(task, returnSignalFieldValue, signalField)
    task.control = "run"
    return promise
end function

function createResolvedPromise(value as dynamic, delay = 0.01 as float) as dynamic
    timer = CreateObject("roSGNode", "Timer")
    timer.duration = delay
    timer.repeat = false
    promise = createPromiseFromNode(timer, false, "fire")
    promise.value = value
    timer.control = "start"
    return promise
end function

function createObservablePromise(signalFieldType = "assocarray" as string, fields = invalid as object, returnSignalFieldValue = false as boolean, signalField = "output" as string) as object
    node = CreateObject("roSGNode", "Node")
    if fields <> invalid then node.addFields(fields)
    node.addField(signalField, signalFieldType, false)
    promise = createPromiseFromNode(node, returnSignalFieldValue, signalField)
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
    promise = createPromiseFromNode(animation, false, "state")
    promise.shouldSendCallback = function(node) as Boolean
        if node.state = "stopped" then return true
        return false
    end function
    promise.unparent = unparentNode

    if startAnimation then animation.control = "start"
    return promise
end function

function createPromiseFromNode(node as object, returnSignalFieldValue as boolean, signalField as string) as object
    promise = __createPromise()
    node.id = promise.id
    node.observeFieldScoped(signalField, "__nodePromiseResolvedHandler")
    promise.signalField = signalField
    promise.node = node
    promise.returnSignalFieldValue = returnSignalFieldValue
    return promise
end function

'---------------------------------------------------------------------
' Everything below here is private and should not be called directly.
'---------------------------------------------------------------------

function __createPromise() as object
    id = StrI(rnd(2147483647), 36)
    promise = {
        then: sub(callback as function)
            m.context[m.id + "_callback"] = callback
        end sub

        dispose: sub()
            if not m.doesExist("context") then return ' already disposed
            m.context.delete(m.id + "_callback")
            m.context.delete(m.id)
            m.delete("context")
            if m.doesExist("node")
                m.node.unobserveFieldScoped(m.signalField)
                m.delete("node")
            end if
        end sub
    }
    promise.context = m
    promise.id = id
    promise.complete = false
    m[id] = promise
    return promise
end function

sub __nodePromiseResolvedHandler(e as object)
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
        else if promise.doesExist("value")
            callback(promise.value)
            promise.delete("value")
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
