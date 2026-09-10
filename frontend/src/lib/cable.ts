import { createConsumer, type Consumer, type Subscription } from '@rails/actioncable'

let consumer: Consumer | null = null

export function getConsumer(): Consumer {
  if (!consumer) {
    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws'
    consumer = createConsumer(`${proto}://${window.location.host}/cable`)
  }
  return consumer
}

export function subscribeConversation<T>(onMessage: (data: T) => void): Subscription {
  return getConsumer().subscriptions.create({ channel: 'ConversationChannel' }, { received: onMessage })
}

export function disconnectCable() {
  consumer?.disconnect()
  consumer = null
}
