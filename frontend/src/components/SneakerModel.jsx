import { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { useGLTF, Environment, ContactShadows } from '@react-three/drei';
import * as THREE from 'three';

// Placeholder cube component with premium materials
function PlaceholderCube({ rotation }) {
    const meshRef = useRef();
    const targetRotation = useRef({ x: 0, y: 0 });

    // Smooth lerp factor
    const lerpFactor = 0.08;

    useFrame(() => {
        if (meshRef.current && rotation) {
            // Update target rotation
            targetRotation.current.x = rotation.x;
            targetRotation.current.y = rotation.y;

            // Apply lerp smoothing
            meshRef.current.rotation.x = THREE.MathUtils.lerp(
                meshRef.current.rotation.x,
                targetRotation.current.x,
                lerpFactor
            );
            meshRef.current.rotation.y = THREE.MathUtils.lerp(
                meshRef.current.rotation.y,
                targetRotation.current.y,
                lerpFactor
            );
        }
    });

    return (
        <mesh ref={meshRef} castShadow receiveShadow>
            <boxGeometry args={[2, 1.2, 3]} />
            <meshPhysicalMaterial
                color="#8b5cf6"
                metalness={0.3}
                roughness={0.2}
                clearcoat={1}
                clearcoatRoughness={0.1}
                envMapIntensity={1.5}
            />
        </mesh>
    );
}

// Sneaker model component
function SneakerMesh({ rotation, gltf }) {
    const meshRef = useRef();
    const targetRotation = useRef({ x: 0, y: 0 });

    const lerpFactor = 0.08;

    // Clone the scene to avoid modifying the cached version
    const clonedScene = useMemo(() => {
        const scene = gltf.scene.clone();
        scene.traverse((child) => {
            if (child.isMesh) {
                child.castShadow = true;
                child.receiveShadow = true;
                // Enhance materials
                if (child.material) {
                    child.material = child.material.clone();
                    child.material.envMapIntensity = 1.5;
                }
            }
        });
        return scene;
    }, [gltf]);

    useFrame(() => {
        if (meshRef.current && rotation) {
            targetRotation.current.x = rotation.x;
            targetRotation.current.y = rotation.y;

            meshRef.current.rotation.x = THREE.MathUtils.lerp(
                meshRef.current.rotation.x,
                targetRotation.current.x,
                lerpFactor
            );
            meshRef.current.rotation.y = THREE.MathUtils.lerp(
                meshRef.current.rotation.y,
                targetRotation.current.y,
                lerpFactor
            );
        }
    });

    return (
        <primitive
            ref={meshRef}
            object={clonedScene}
            scale={15}
            position={[0, -0.5, 0]}
        />
    );
}

// Main sneaker model wrapper with fallback
export default function SneakerModel({ rotation }) {
    // Try to load a free sneaker model from Sketchfab
    // Using a placeholder URL - in production, use a proper hosted model
    let gltf = null;
    let loadError = false;

    try {
        // Free sneaker model from Sketchfab (public domain)
        // This is a fallback URL pattern - actual model may need to be hosted
        gltf = useGLTF('https://vazxmixjsiawhamofees.supabase.co/storage/v1/object/public/models/shoe-draco/model.gltf');
    } catch (e) {
        loadError = true;
    }

    return (
        <group>
            {gltf && !loadError ? (
                <SneakerMesh rotation={rotation} gltf={gltf} />
            ) : (
                <PlaceholderCube rotation={rotation} />
            )}

            {/* Ambient lighting */}
            <ambientLight intensity={0.4} />

            {/* Key light */}
            <spotLight
                position={[10, 10, 10]}
                angle={0.3}
                penumbra={1}
                intensity={2}
                castShadow
                shadow-mapSize-width={2048}
                shadow-mapSize-height={2048}
            />

            {/* Fill light */}
            <spotLight
                position={[-10, 5, -10]}
                angle={0.3}
                penumbra={1}
                intensity={1}
                color="#a855f7"
            />

            {/* Rim light */}
            <pointLight position={[0, 5, -10]} intensity={1} color="#0ea5e9" />

            {/* Environment for reflections */}
            <Environment preset="city" />

            {/* Contact shadows */}
            <ContactShadows
                position={[0, -1.5, 0]}
                opacity={0.6}
                scale={10}
                blur={2}
                far={4}
            />
        </group>
    );
}

// Preload the model
try {
    useGLTF.preload('https://vazxmixjsiawhamofees.supabase.co/storage/v1/object/public/models/shoe-draco/model.gltf');
} catch (e) {
    // Silently fail - will use placeholder
}
