export const successResponse = (data, message = 'Success', meta = {}) => ({
  success: true,
  message,
  data,
  ...meta,
});

export const errorResponse = (message, statusCode = 400) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

export const paginationMeta = (total, page, limit) => ({
  pagination: {
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  },
});
