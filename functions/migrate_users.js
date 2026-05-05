const admin = require('firebase-admin');

// Initialize with your project ID
admin.initializeApp({
  projectId: 'vista-jklu'
});

const db = admin.firestore();

async function migrate() {
  console.log('Starting migration...');
  const usersSnap = await db.collection('users').get();
  
  let count = 0;
  const batch = db.batch();
  
  // You can set this to the start of the semester or today
  const defaultDate = new Date('2025-02-10T00:00:00Z'); 

  usersSnap.forEach(doc => {
    const data = doc.data();
    if (!data.createdAt) {
      batch.update(doc.ref, {
        createdAt: admin.firestore.Timestamp.fromDate(defaultDate)
      });
      count++;
    }
  });

  if (count > 0) {
    await batch.commit();
    console.log(`Successfully updated ${count} users with default createdAt.`);
  } else {
    console.log('No users needed updating.');
  }
}

migrate().catch(console.error);
