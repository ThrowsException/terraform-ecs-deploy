// Require the framework and instantiate it
const client = require('./prismaClient');
const fastify = require('fastify')({ logger: true });

// Declare a route
fastify.get('/', async (request, reply) => {
  const result = await client.$queryRaw`SELECT COUNT(1)`;
  return { goodbye: result };
});

// Run the server!
const start = async () => {
  try {
    await fastify.listen(process.env.PORT || 3000, '0.0.0.0');
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};
start();
