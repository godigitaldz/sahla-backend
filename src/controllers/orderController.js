import orderService from '../services/orderService.js';
import { paginationMeta, successResponse } from '../utils/response.js';

export const getOrders = async (req, res, next) => {
  try {
    const userId = req.user?.id; // From auth middleware
    const { status, limit = 50, offset = 0 } = req.query;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const { data, count } = await orderService.getOrders({
      userId,
      status,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

    res.json(successResponse(
      data,
      'Orders retrieved successfully',
      paginationMeta(count, Math.floor(offset / limit) + 1, parseInt(limit))
    ));
  } catch (error) {
    next(error);
  }
};

export const createOrder = async (req, res, next) => {
  try {
    const userId = req.user?.id; // From auth middleware

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const orderData = {
      userId,
      ...req.body,
    };

    const data = await orderService.createOrder(orderData);

    res.status(201).json(successResponse(data, 'Order created successfully'));
  } catch (error) {
    next(error);
  }
};

export const getOrderById = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const data = await orderService.getOrderById(id, userId);

    if (!data) {
      return res.status(404).json({
        success: false,
        error: 'Order not found',
      });
    }

    res.json(successResponse(data, 'Order retrieved successfully'));
  } catch (error) {
    next(error);
  }
};

export const updateOrderStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      return res.status(400).json({
        success: false,
        error: 'Status is required',
      });
    }

    const data = await orderService.updateOrderStatus(id, status);

    res.json(successResponse(data, 'Order status updated successfully'));
  } catch (error) {
    next(error);
  }
};
