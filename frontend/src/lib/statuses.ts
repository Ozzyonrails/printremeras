import type { OrderStatus } from '../api/types'

/** Happy-path order pipeline (spec §13). Branches by shipping method after in_production. */
export const PIPELINE_PICKUP: OrderStatus[] = ['pending_approval', 'awaiting_payment', 'paid', 'preparing', 'in_production', 'ready_for_pickup', 'delivered']
export const PIPELINE_COURIER: OrderStatus[] = ['pending_approval', 'awaiting_payment', 'paid', 'preparing', 'in_production', 'awaiting_courier', 'in_transit', 'delivered']
export const EXCEPTION_STATUSES: OrderStatus[] = ['rejected', 'cancelled', 'problem', 'refunded']

export function isExceptionStatus(s: OrderStatus) {
  return EXCEPTION_STATUSES.includes(s)
}
