const { initializeApp } = require("firebase/app");
const { getAuth, createUserWithEmailAndPassword } = require("firebase/auth");
const { getFirestore, doc, setDoc } = require("firebase/firestore");

const firebaseConfig = {
    apiKey: "AIzaSyC89dCMuTOETtpjJbGj2ZvVA6tdvGaxzZY",
    authDomain: "vista-jklu.firebaseapp.com",
    projectId: "vista-jklu",
    storageBucket: "vista-jklu.firebasestorage.app",
    measurementId: "G-F4L0EFZCDS",
    appId: "1:453696388011:web:089e90e69035e8cee3f0ee"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function create() {
    try {
        const userCredential = await createUserWithEmailAndPassword(auth, "chief@jklu.edu.in", "chiefchief");
        const uid = userCredential.user.uid;
        await setDoc(doc(db, "users", uid), {
            uid: uid,
            email: "chief@jklu.edu.in",
            name: "Chief Warden",
            role: "Chief Warden",
            hostel: "All", 
            isApproved: true,
            createdAt: new Date().toISOString()
        });
        console.log("Success! UID:", uid);
        process.exit(0);
    } catch(e) {
        console.error("Error:", e);
        process.exit(1);
    }
}
create();
