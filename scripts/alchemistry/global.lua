return {
  eventHandlers = {
    alchemistryRemoveItem = function(data)
      data.gameObject:remove(data.count)
    end
  }
}
