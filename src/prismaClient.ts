import {PrismaClient} from '@prisma/client';
import RDS from 'aws-sdk/clients/rds';

// 10 minutes
// DB_PASSWORD_EXPIRY_MINS = 1 * 60000;


declare global {
  // allow global `var` declarations
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined
}

const generateClient = async () => {
  const signer = new RDS.Signer({
    // configure options
    region: 'us-east-1',
    username: 'iam_user',
    hostname: 'database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com',
    port: 5432,
  });
  const token = signer.getAuthToken({});
  console.log(token);
  global.prisma = new PrismaClient({
    datasources: {
      db: {
        url: `postgresql://iam_user:${encodeURIComponent(
          token
        )}@database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com:5432/test?schema=public`,
      },
    },
    log: ['query', 'info', 'warn', 'error'],
  });

  setInterval(async () => {
    await global.prisma?.$disconnect();
    const token = signer.getAuthToken({});
    console.log(token);
    global.prisma = new PrismaClient({
      datasources: {
        db: {
          url: `postgresql://iam_user:${encodeURIComponent(
            token
          )}@database-1.c1v245smnlqu.us-east-1.rds.amazonaws.com:5432/test?schema=public`,
        },
      },
      log: ['query', 'info', 'warn', 'error'],
    });
    global.prisma?.$connect()
  }, 2000);

  await global.prisma.$connect();
  return global.prisma;
};
generateClient();

module.exports = global.prisma;
