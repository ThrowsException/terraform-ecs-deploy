const fp = require('fastify-plugin');
const { PrismaClient } = require('@prisma/client');
const RDS = require('aws-sdk/clients/rds');

// 10 minutes
// DB_PASSWORD_EXPIRY_MINS = 1 * 60000;

let prisma;
const prismaPlugin = fp(async (server, options) => {
  const signer = new RDS.Signer({
    // configure options
    region: 'us-east-1',
    username: 'iam_user',
    hostname: 'database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com',
    port: 5432,
  });
  const token = signer.getAuthToken();
  console.log(token);
  prisma = new PrismaClient({
    datasources: {
      db: {
        url: `postgresql://iam_user:${encodeURIComponent(
          token
        )}@database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com:5432/test?schema=public`,
      },
    },
    log: ['query', 'info', 'warn', 'error'],
  });
  await prisma.$connect();

  setInterval(async () => {
    await prisma.$disconnect();
    console.log(prisma);
    const token = signer.getAuthToken();
    console.log(token);
    prisma.prisma = new PrismaClient({
      datasources: {
        db: {
          url: `postgresql://iam_user:${encodeURIComponent(
            token
          )}@database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com:5432/test?schema=public`,
        },
      },
      log: ['query', 'info', 'warn', 'error'],
    });
    await prisma.$connect();
  }, 2000);

  // Make Prisma Client available through the fastify server instance: server.prisma
  server.decorate('prisma', prisma);
  server.addHook('onClose', async (server) => {
    await server.prisma.$disconnect();
  });
});

module.exports = prismaPlugin;
